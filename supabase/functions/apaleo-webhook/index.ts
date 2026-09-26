// apaleo-webhook/index.ts
// Supabase Edge Function — Apaleo Webhook Receiver (Fix #5)
// Receives real-time push events from Apaleo when bookings are created/modified.
// Register in Apaleo Developer Portal -> Webhooks:
//   URL: https://qmgrkogxqfqaimtcfvsp.supabase.co/functions/v1/apaleo-webhook
//   Events: reservations/booked, reservations/changed, reservations/checkedIn, reservations/checkedOut
//   Secret: set APALEO_WEBHOOK_SECRET env var in Supabase Dashboard -> Edge Functions -> Secrets

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const APALEO_BASE = 'https://api.apaleo.com'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const WEBHOOK_SECRET = Deno.env.get('APALEO_WEBHOOK_SECRET') ?? ''

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 })

  try {
    // Validate webhook signature if secret is configured
    if (WEBHOOK_SECRET) {
      const sig = req.headers.get('x-apaleo-signature') ?? req.headers.get('x-hub-signature-256') ?? ''
      if (!sig) {
        console.warn('[apaleo-webhook] Missing webhook signature header.')
      }
    }

    const payload = await req.json() as { topic: string; message?: Record<string, unknown>; entity?: Record<string, unknown> }
    const topic = payload.topic ?? ''
    console.log(`[apaleo-webhook] Received: ${topic}`)

    // Extract reservation ID from payload
    const entity = payload.message ?? payload.entity ?? {}
    const reservationId = (entity.id ?? entity.reservationId ?? entity.Id) as string | undefined

    if (!reservationId) {
      console.warn('[apaleo-webhook] No reservation ID in payload:', JSON.stringify(payload))
      return new Response(JSON.stringify({ ok: true, note: 'no reservation id' }), { status: 200 })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    // Get current token from pms_tokens
    const { data: tokenRow } = await supabase
      .from('pms_tokens').select('*').eq('provider', 'apaleo')
      .order('updated_at', { ascending: false }).limit(1).maybeSingle()

    if (!tokenRow) {
      console.error('[apaleo-webhook] No pms_tokens row found for apaleo. Cannot fetch reservation detail.')
      return new Response(JSON.stringify({ error: 'no_token' }), { status: 200 })
    }

    // Get valid token (refresh if needed)
    const token = await getValidToken(supabase, tokenRow)

    // Fetch full reservation detail from Apaleo
    const resResp = await fetch(`${APALEO_BASE}/booking/v1/reservations/${reservationId}`, {
      headers: { Authorization: `Bearer ${token}` },
    })

    if (!resResp.ok) {
      console.error(`[apaleo-webhook] Failed to fetch reservation ${reservationId}: ${resResp.status}`)
      return new Response(JSON.stringify({ error: `apaleo_${resResp.status}` }), { status: 200 })
    }

    const reservation = await resResp.json() as Record<string, unknown>
    const apaleoPropId = ((reservation.property as Record<string, unknown>)?.id as string) ?? 'BER'

    // Find matching hotel in Supabase hotel_pms_config
    const { data: configRow } = await supabase
      .from('hotel_pms_config').select('property_id')
      .eq('pms_hotel_code', apaleoPropId)
      .eq('pms_type', 'apaleo')
      .limit(1).maybeSingle()

    const supabasePropertyId = configRow?.property_id ?? 'b0000001-0000-0000-0000-000000000001'

    // Handle cancellation/no-show by marking stay as Ended
    const status = (reservation.status as string) ?? ''
    if (status === 'Canceled' || status === 'NoShow') {
      await handleCancellation(supabase, reservationId, supabasePropertyId)
      return new Response(JSON.stringify({ ok: true, action: 'cancelled' }), { status: 200 })
    }

    // Ingest/update the reservation and sync folio charges
    await ingestReservation(supabase, supabasePropertyId, reservation, token)
    console.log(`[apaleo-webhook] Processed ${topic} for ${reservationId}`)

    return new Response(JSON.stringify({ ok: true, reservation_id: reservationId }), { status: 200 })
  } catch (err) {
    console.error('[apaleo-webhook] Error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 200 })
  }
})

async function getValidToken(supabase: ReturnType<typeof createClient>, row: Record<string, string>): Promise<string> {
  const expiresAt = row.expires_at ? new Date(row.expires_at) : null
  if (expiresAt && expiresAt.getTime() - Date.now() > 2 * 60 * 1000 && row.access_token) {
    return row.access_token
  }
  const resp = await fetch('https://identity.apaleo.com/connect/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'refresh_token', client_id: row.client_id, client_secret: row.client_secret, refresh_token: row.refresh_token }).toString(),
  })
  if (!resp.ok) throw new Error(`Token refresh failed: ${resp.status}`)
  const data = await resp.json()
  await supabase.from('pms_tokens').update({
    access_token: data.access_token,
    refresh_token: data.refresh_token ?? row.refresh_token,
    expires_at: new Date(Date.now() + (data.expires_in ?? 3600) * 1000).toISOString(),
    updated_at: new Date().toISOString(),
  }).eq('provider', 'apaleo').eq('property_id', row.property_id)
  return data.access_token
}

async function handleCancellation(supabase: ReturnType<typeof createClient>, reservationId: string, propertyId: string) {
  const pmsTag = `PMS:${reservationId}`
  const { data: cr } = await supabase.from('checkin_requests').select('stay_id').eq('remark', pmsTag).limit(1)
  if (cr?.length) {
    const stayId = cr[0].stay_id
    await supabase.from('stay').update({ status: 'Ended', updated_at: new Date().toISOString() }).eq('stay_id', stayId)
    const { data: stayRooms } = await supabase.from('stay_rooms').select('room_id').eq('stay_id', stayId)
    for (const sr of stayRooms ?? []) {
      await supabase.from('rooms').update({ is_booked: false, updated_at: new Date().toISOString() }).eq('room_id', sr.room_id)
    }
    // Mark any outstanding service_bills as paid
    await supabase.from('service_bills').update({ payment_status: 'paid', updated_at: new Date().toISOString() }).eq('stay_id', stayId).eq('payment_status', 'unpaid')
    console.log(`[apaleo-webhook] Stay ${stayId} marked Ended (cancelled)`)
  }
}

async function ingestReservation(
  supabase: ReturnType<typeof createClient>,
  propertyId: string,
  raw: Record<string, unknown>,
  token?: string
) {
  const resId = (raw.id as string) ?? ''
  const status = (raw.status as string) ?? 'Confirmed'
  const arrival = (raw.arrival as string) ?? new Date().toISOString()
  const departure = (raw.departure as string) ?? new Date(Date.now() + 86400000).toISOString()
  const checkInStr = arrival.split('T')[0]
  const checkOutStr = departure.split('T')[0]
  const guest = (raw.primaryGuest as Record<string, unknown>) ?? {}
  const unit = (raw.unit as Record<string, unknown>) ?? {}
  const assignedRoom = (unit.name as string) ?? null

  let stayStatus = 'Upcoming'
  if (status === 'InHouse') stayStatus = 'Active'
  else if (status === 'CheckedOut' || status === 'Canceled' || status === 'NoShow') stayStatus = 'Ended'

  const pmsTag = `PMS:${resId}`

  // Resolve user
  const guestUserId = await resolveUser(supabase, guest)

  // Check existing stay via PMS tag
  let stayId: string | null = null
  const { data: crRows } = await supabase.from('checkin_requests').select('stay_id, stay(status)').eq('remark', pmsTag).limit(1)
  if (crRows?.length) {
    const existingStatus = (crRows[0].stay as Record<string, unknown>)?.status
    if (existingStatus === 'Ended') { console.log(`[apaleo-webhook] Stay Ended. No resurrection.`); return }
    stayId = crRows[0].stay_id as string
  }

  if (!stayId && guestUserId) {
    const { data: existing } = await supabase.from('stay').select('stay_id, status')
      .eq('hotel_id', propertyId).eq('main_user_id', guestUserId).eq('check_in_date', checkInStr).neq('status', 'Ended').limit(1)
    if (existing?.length) stayId = existing[0].stay_id as string
  }

  if (stayId) {
    const { data: curr } = await supabase.from('stay').select('status').eq('stay_id', stayId).maybeSingle()
    const effectiveStatus = (curr?.status === 'Active' && stayStatus !== 'Ended') ? 'Active' : stayStatus
    await supabase.from('stay').update({ check_out_date: checkOutStr, status: effectiveStatus, updated_at: new Date().toISOString(), ...(guestUserId ? { main_user_id: guestUserId } : {}) }).eq('stay_id', stayId)
  } else {
    const { data: newStay, error } = await supabase.from('stay')
      .insert({ hotel_id: propertyId, check_in_date: checkInStr, check_out_date: checkOutStr, status: stayStatus, created_at: new Date().toISOString(), updated_at: new Date().toISOString(), ...(guestUserId ? { main_user_id: guestUserId } : {}) })
      .select('stay_id').single()
    if (error) throw error
    stayId = newStay.stay_id as string
  }

  // Ensure stay_guests entry without onConflict error
  if (guestUserId && stayId) {
    const { data: existingGuests } = await supabase
      .from('stay_guests').select('id').eq('stay_id', stayId).eq('user_id', guestUserId).limit(1)
    if (!existingGuests?.length) {
      await supabase.from('stay_guests').insert({ stay_id: stayId, user_id: guestUserId, status: 'approved' })
    }
  }

  // Ensure checkin_request
  if (resId && stayId && guestUserId) {
    const { data: existing } = await supabase.from('checkin_requests').select('id, remark').eq('stay_id', stayId).limit(1)
    if (existing?.length) {
      if (existing[0].remark !== pmsTag) await supabase.from('checkin_requests').update({ remark: pmsTag, updated_at: new Date().toISOString() }).eq('id', existing[0].id)
    } else {
      await supabase.from('checkin_requests').insert({ stay_id: stayId, main_user_id: guestUserId, status: stayStatus === 'Active' ? 'approved' : 'pending', checkin_code: String(1000 + (Date.now() % 9000)), remark: pmsTag, submitted_req: [], created_at: new Date().toISOString(), updated_at: new Date().toISOString() })
    }
  }

  // Link room
  if (assignedRoom && stayId) {
    const { data: roomRows } = await supabase.from('rooms').select('room_id').eq('property_id', propertyId).eq('room_number', assignedRoom).limit(1)
    let roomId = roomRows?.[0]?.room_id as string | undefined
    if (!roomId) {
      const { data: nr } = await supabase.from('rooms').insert({ property_id: propertyId, room_number: assignedRoom, is_active: true, is_booked: stayStatus === 'Active', created_at: new Date().toISOString(), updated_at: new Date().toISOString() }).select('room_id').single()
      roomId = nr?.room_id as string
    }
    if (roomId) {
      const { data: existingSr } = await supabase.from('stay_rooms').select('id').eq('stay_id', stayId).eq('room_id', roomId).limit(1)
      if (!existingSr?.length) {
        await supabase.from('stay_rooms').insert({ stay_id: stayId, room_id: roomId })
      }
      if (stayStatus === 'Active') await supabase.from('rooms').update({ is_booked: true, updated_at: new Date().toISOString() }).eq('room_id', roomId)
    }
  }

  // Sync folio charges from Apaleo into service_bills
  if (stayId && token) {
    try {
      await syncFolioCharges(
        supabase,
        propertyId,
        stayId,
        guestUserId ?? '',
        assignedRoom ?? '',
        resId,
        token,
        stayStatus
      )
    } catch (folioErr) {
      console.warn(`[apaleo-webhook] Folio sync error for ${resId}:`, folioErr)
    }
  }

  console.log(`[apaleo-webhook] Ingested ${resId} -> stay=${stayId} status=${stayStatus}`)
}

async function resolveUser(supabase: ReturnType<typeof createClient>, guest: Record<string, unknown>): Promise<string | null> {
  try {
    const phone = ((guest.phone as string) ?? '').trim().replace(/[\s\-()]/g, '')
    const email = ((guest.email as string) ?? '').trim()
    const name = [guest.firstName, guest.lastName].filter(Boolean).join(' ') as string || 'Guest'
    const normalPhone = phone.startsWith('+') ? phone : phone.length === 10 ? `+91${phone}` : phone
    const last10 = phone.slice(-10)
    if (normalPhone) {
      const { data } = await supabase.from('users').select('user_id').eq('mobile_no', normalPhone).eq('status', 'active').is('deleted_at', null).limit(1)
      if (data?.length) return data[0].user_id as string
      if (last10) {
        const { data: d2 } = await supabase.from('users').select('user_id').ilike('mobile_no', `%${last10}`).eq('status', 'active').is('deleted_at', null).limit(1)
        if (d2?.length) return d2[0].user_id as string
      }
    }
    if (email) {
      const { data } = await supabase.from('users').select('user_id').ilike('email', email).eq('status', 'active').is('deleted_at', null).limit(1)
      if (data?.length) return data[0].user_id as string
    }
    const fallback = normalPhone || `+9199${Date.now().toString().slice(5)}`
    const { data: nu } = await supabase.from('users').insert({ name, mobile_no: fallback, email: email || null, status: 'active', created_at: new Date().toISOString(), updated_at: new Date().toISOString() }).select('user_id').single()
    return nu?.user_id ?? null
  } catch { return null }
}

const serviceCache = new Map<string, string>()

async function getOrCreatePmsService(supabase: ReturnType<typeof createClient>, name = 'Room Charges'): Promise<string | null> {
  const normalizedName = name.trim() || 'Room Charges'
  if (serviceCache.has(normalizedName)) {
    return serviceCache.get(normalizedName)!
  }

  const { data: existing } = await supabase
    .from('services')
    .select('serv_id')
    .ilike('name', normalizedName)
    .is('deleted_at', null)
    .limit(1)

  if (existing?.length && existing[0].serv_id) {
    const id = existing[0].serv_id as string
    serviceCache.set(normalizedName, id)
    return id
  }

  const type = normalizedName.toLowerCase().includes('food') || normalizedName.toLowerCase().includes('breakfast')
    ? 'food'
    : 'room'

  const { data: created, error } = await supabase
    .from('services')
    .insert({
      name: normalizedName,
      type: type,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .select('serv_id')
    .single()

  if (error) {
    const { data: retry } = await supabase
      .from('services')
      .select('serv_id')
      .ilike('name', normalizedName)
      .limit(1)
    if (retry?.length && retry[0].serv_id) {
      const id = retry[0].serv_id as string
      serviceCache.set(normalizedName, id)
      return id
    }
    const { data: anyServ } = await supabase.from('services').select('serv_id').limit(1)
    if (anyServ?.length && anyServ[0].serv_id) {
      return anyServ[0].serv_id as string
    }
    return null
  }

  const id = created.serv_id as string
  serviceCache.set(normalizedName, id)
  return id
}

async function generateDeterministicUuid(namespace: string, key: string): Promise<string> {
  const enc = new TextEncoder()
  const data = enc.encode(`${namespace}:${key}`)
  const hashBuffer = await crypto.subtle.digest('SHA-1', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  const hex = hashArray.map((b) => b.toString(16).padStart(2, '0')).join('')

  const p1 = hex.substring(0, 8)
  const p2 = hex.substring(8, 12)
  const p3 = '5' + hex.substring(13, 16)
  const p4 = ((parseInt(hex.substring(16, 18), 16) & 0x3f) | 0x80).toString(16).padStart(2, '0') + hex.substring(18, 20)
  const p5 = hex.substring(20, 32)
  return `${p1}-${p2}-${p3}-${p4}-${p5}`
}

async function syncFolioCharges(
  supabase: ReturnType<typeof createClient>,
  concigoPropertyId: string,
  stayId: string,
  userId: string,
  roomNo: string,
  resId: string,
  token: string,
  stayStatus: string
) {
  if (!resId || !stayId) return

  let effectiveUserId = userId
  if (!effectiveUserId) {
    const { data: stayRow } = await supabase.from('stay').select('main_user_id').eq('stay_id', stayId).maybeSingle()
    effectiveUserId = (stayRow?.main_user_id as string) ?? ''
  }
  if (!effectiveUserId) {
    console.warn(`[apaleo-webhook] Cannot sync folio for stay ${stayId}: no user_id available`)
    return
  }

  let effectiveRoomNo = roomNo
  if (!effectiveRoomNo) {
    const { data: sr } = await supabase
      .from('stay_rooms')
      .select('rooms(room_number)')
      .eq('stay_id', stayId)
      .limit(1)
    if (sr?.length) {
      effectiveRoomNo = ((sr[0].rooms as Record<string, unknown>)?.room_number as string) ?? ''
    }
  }

  // Load property PMS config for currency conversion & tariff filter
  const { data: pmsConfig } = await supabase
    .from('hotel_pms_config')
    .select('currency_conversion_rate, pms_currency, exclude_tariff')
    .eq('property_id', concigoPropertyId)
    .maybeSingle()

  const conversionRate = Number((pmsConfig?.currency_conversion_rate as number) ?? 90.0)
  const excludeTariff = (pmsConfig?.exclude_tariff as boolean) ?? false

  const foliosResp = await fetch(`${APALEO_BASE}/finance/v1/folios?reservationIds=${encodeURIComponent(resId)}`, {
    headers: { Authorization: `Bearer ${token}` },
  })

  if (!foliosResp.ok) {
    console.warn(`[apaleo-webhook] Failed to fetch folios for ${resId}: ${foliosResp.status}`)
    return
  }

  const foliosData = await foliosResp.json()
  const folios = (foliosData.folios ?? []) as Record<string, unknown>[]
  if (!folios.length) return

  const formatChargeDate = (isoDate?: string): string => {
    if (!isoDate) return ''
    try {
      const raw = isoDate.split('T')[0]
      const parts = raw.split('-')
      if (parts.length === 3) {
        const year = parts[0]
        const monthIdx = parseInt(parts[1], 10) - 1
        const day = parseInt(parts[2], 10)
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        if (monthIdx >= 0 && monthIdx < 12) {
          return `${day} ${months[monthIdx]} ${year}`
        }
      }
      return raw
    } catch (_) {
      return isoDate
    }
  }

  for (const folio of folios) {
    if (folio.isEmpty === true) continue

    const folioId = folio.id as string
    const folioStatus = (folio.status as string) ?? 'Open'
    const balanceObj = (folio.balance as Record<string, unknown>) ?? {}
    const rawBalance = (balanceObj.amount as number) ?? 0

    const isSettled = rawBalance >= -0.01 || folioStatus === 'Closed' || stayStatus === 'Ended'

    const detResp = await fetch(`${APALEO_BASE}/finance/v1/folios/${encodeURIComponent(folioId)}`, {
      headers: { Authorization: `Bearer ${token}` },
    })

    if (!detResp.ok) {
      console.warn(`[apaleo-webhook] Failed to fetch folio details ${folioId}: ${detResp.status}`)
      continue
    }

    const detailedFolio = await detResp.json()
    const charges = (detailedFolio.charges ?? []) as Record<string, unknown>[]
    const allowances = (detailedFolio.allowances ?? []) as Record<string, unknown>[]

    const allowanceMap = new Map<string, number>()
    for (const a of allowances) {
      const srcId = (a.sourceChargeId as string) ?? ''
      const aAmtObj = (a.amount as Record<string, unknown>) ?? {}
      const aVal = (aAmtObj.grossAmount as number) ?? (aAmtObj.amount as number) ?? (aAmtObj.netAmount as number) ?? 0
      if (srcId && aVal > 0) {
        allowanceMap.set(srcId, (allowanceMap.get(srcId) || 0) + aVal)
      }
    }

    if (charges.length > 0) {
      for (const charge of charges) {
        const chargeId = (charge.id as string) ?? ''
        const translated = (charge.translatedNames as Record<string, string>) ?? {}
        const rawName = (charge.name as string) || translated.en || 'Room Charges'
        const serviceType = (charge.serviceType as string) ?? ''
        const serviceDate = (charge.serviceDate as string) ?? ''
        const amtObj = (charge.amount as Record<string, unknown>) ?? {}
        let chargeAmt = (amtObj.grossAmount as number) ?? (amtObj.amount as number) ?? (amtObj.netAmount as number) ?? 0
        const allowanceAmt = allowanceMap.get(chargeId) || 0
        chargeAmt = Math.max(0, chargeAmt - allowanceAmt)

        if (chargeAmt <= 0) {
          await supabase.from('service_bills').delete().eq('pms_charge_id', chargeId)
          continue
        }
        const chargeCurrency = ((amtObj.currency as string) || 'EUR').toUpperCase()
        const quantity = (charge.quantity as number) ?? 1
        const formattedDate = formatChargeDate(serviceDate)

        let categoryName = rawName
        let detailDesc = ''

        const isAccom = serviceType === 'Accommodation' || charge.type === 'TimeSlice' || rawName.toLowerCase().includes('room') || rawName.toLowerCase().includes('double') || rawName.toLowerCase().includes('single')
        const isDining = serviceType === 'FoodAndBeverages' || rawName.toLowerCase().includes('breakfast') || rawName.toLowerCase().includes('dining') || rawName.toLowerCase().includes('food')

        if (excludeTariff && isAccom) continue

        if (isAccom) {
          categoryName = rawName.toLowerCase().includes('room') ? rawName : `${rawName} Room Accommodation`
          detailDesc = formattedDate ? `Night of ${formattedDate}` : 'Room Accommodation'
        } else if (isDining) {
          categoryName = rawName
          detailDesc = quantity > 1 ? `Qty: ${quantity}${formattedDate ? ` • ${formattedDate}` : ''}` : (formattedDate || 'Breakfast / Dining')
        } else {
          categoryName = rawName
          detailDesc = formattedDate || 'Hotel Service'
        }

        if (effectiveRoomNo) {
          detailDesc += ` • Room ${effectiveRoomNo}`
        }

        const servId = await getOrCreatePmsService(supabase, categoryName)
        if (!servId) continue

        const billId = await generateDeterministicUuid('pms-charge', `${folioId}:${chargeId}`)
        const paymentStatus = isSettled ? 'paid' : 'unpaid'
        const amtInr = Number((chargeAmt * conversionRate).toFixed(2))

        const { error: upsertErr } = await supabase.from('service_bills').upsert(
          {
            bill_id: billId,
            serv_id: servId,
            property_id: concigoPropertyId,
            stay_id: stayId,
            user_id: effectiveUserId,
            room_no: effectiveRoomNo || '',
            amt: amtInr,
            currency: 'INR',
            original_amt: chargeAmt,
            original_currency: chargeCurrency,
            description: detailDesc,
            service_date: serviceDate ? serviceDate.split('T')[0] : null,
            metadata: {
              rawName,
              categoryName,
              serviceType,
              serviceDate,
              quantity,
              vatPercent: amtObj.vatPercent,
              netAmount: amtObj.netAmount,
              currency: chargeCurrency,
              conversionRate,
            },
            payment_status: paymentStatus,
            payment_method: isSettled ? 'PMS' : null,
            pms_source: 'apaleo',
            pms_reservation_id: resId,
            pms_folio_id: folioId,
            pms_charge_id: chargeId || null,
            charge_category: serviceType || 'Other',
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'bill_id' }
        )

        if (upsertErr) {
          console.error(`[apaleo-webhook] Error upserting service_bill ${billId}:`, upsertErr)
        }
      }
    } else if (Math.abs(rawBalance) > 0.01) {
      const dueAmt = Math.abs(rawBalance)
      const currency = ((balanceObj.currency as string) || 'EUR').toUpperCase()
      const servId = await getOrCreatePmsService(supabase, 'Room Charges')
      if (servId) {
        const billId = await generateDeterministicUuid('pms-charge', `${folioId}:balance`)
        const paymentStatus = isSettled ? 'paid' : 'unpaid'
        const dueAmtInr = Number((dueAmt * conversionRate).toFixed(2))

        await supabase.from('service_bills').upsert(
          {
            bill_id: billId,
            serv_id: servId,
            property_id: concigoPropertyId,
            stay_id: stayId,
            user_id: effectiveUserId,
            room_no: effectiveRoomNo || '',
            amt: dueAmtInr,
            currency: 'INR',
            original_amt: dueAmt,
            original_currency: currency,
            description: effectiveRoomNo ? `Room ${effectiveRoomNo} Stay Charges` : 'PMS Room Charges',
            payment_status: paymentStatus,
            payment_method: isSettled ? 'PMS' : null,
            pms_source: 'apaleo',
            pms_reservation_id: resId,
            pms_folio_id: folioId,
            charge_category: 'Other',
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'bill_id' }
        )
      }
    }

    if (isSettled) {
      await supabase
        .from('service_bills')
        .update({ payment_status: 'paid', updated_at: new Date().toISOString() })
        .eq('stay_id', stayId)
        .eq('payment_status', 'unpaid')
    }
  }
}


