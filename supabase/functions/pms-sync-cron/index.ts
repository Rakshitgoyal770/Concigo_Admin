// pms-sync-cron/index.ts
// Supabase Edge Function — High-Performance Server-Side PMS Sync
// Runs every 2 minutes via Supabase pg_cron or can be triggered via HTTP.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const APALEO_BASE = 'https://api.apaleo.com'
const APALEO_TOKEN_URL = 'https://identity.apaleo.com/connect/token'
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

function extractJwtExpiry(jwt: string): Date | null {
  try {
    const parts = jwt.split('.')
    if (parts.length !== 3) return null
    const normalized = parts[1].replace(/-/g, '+').replace(/_/g, '/')
    const payload = JSON.parse(atob(normalized))
    if (payload.exp) return new Date(payload.exp * 1000)
  } catch (_) {}
  return null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
  const results: Record<string, unknown>[] = []

  try {
    const { data: tokenRows, error: tokErr } = await supabase
      .from('pms_tokens')
      .select('provider, property_id, access_token, refresh_token, client_id, client_secret, expires_at')
      .eq('provider', 'apaleo')

    if (tokErr || !tokenRows?.length) {
      console.warn('[pms-sync-cron] No pms_tokens rows found.', tokErr)
      return new Response(JSON.stringify({ status: 'no_tokens', message: 'No Apaleo credentials in pms_tokens.' }), { status: 200, headers: { 'Content-Type': 'application/json' } })
    }

    for (const row of tokenRows) {
      try {
        const result = await syncProperty(supabase, row)
        results.push({ property_id: row.property_id, ...result })
      } catch (err) {
        console.error(`[pms-sync-cron] Property ${row.property_id} error:`, err)
        results.push({ property_id: row.property_id, error: String(err) })
      }
    }

    return new Response(JSON.stringify({ status: 'ok', results }), { status: 200, headers: { 'Content-Type': 'application/json' } })
  } catch (err) {
    console.error('[pms-sync-cron] Critical error:', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { 'Content-Type': 'application/json' } })
  }
})

async function getValidToken(supabase: ReturnType<typeof createClient>, row: Record<string, string>, forceRefresh = false): Promise<string> {
  const jwtExpiry = row.access_token ? extractJwtExpiry(row.access_token) : null
  const dbExpiry = row.expires_at ? new Date(row.expires_at) : null
  const expiresAt = jwtExpiry ?? dbExpiry

  const isExpiring = !expiresAt || expiresAt.getTime() - Date.now() < 2 * 60 * 1000

  if (!forceRefresh && !isExpiring && row.access_token) {
    return row.access_token
  }

  console.log(`[pms-sync-cron] Refreshing token (forceRefresh=${forceRefresh})...`)
  const resp = await fetch(APALEO_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      client_id: row.client_id,
      client_secret: row.client_secret,
      refresh_token: row.refresh_token,
    }).toString(),
  })

  if (!resp.ok) {
    const body = await resp.text()
    throw new Error(`Token refresh failed ${resp.status}: ${body}`)
  }

  const data = await resp.json()
  const newExpiry = new Date(Date.now() + (data.expires_in ?? 3600) * 1000).toISOString()

  row.access_token = data.access_token
  if (data.refresh_token) row.refresh_token = data.refresh_token
  row.expires_at = newExpiry

  await supabase.from('pms_tokens').update({
    access_token: data.access_token,
    refresh_token: data.refresh_token ?? row.refresh_token,
    expires_at: newExpiry,
    updated_at: new Date().toISOString(),
  }).eq('provider', row.provider).eq('property_id', row.property_id)

  console.log(`[pms-sync-cron] Token refreshed. Valid until ${newExpiry}`)
  return data.access_token
}

async function syncProperty(supabase: ReturnType<typeof createClient>, row: Record<string, string>) {
  let token = await getValidToken(supabase, row)

  const { data: pmsConfigs } = await supabase
    .from('hotel_pms_config')
    .select('property_id, pms_hotel_code')
    .eq('pms_type', 'apaleo')

  const propertyMappings: { concigoPropertyId: string; apaleoHotelCode: string }[] = []
  if (pmsConfigs?.length) {
    for (const cfg of pmsConfigs) {
      if (cfg.pms_hotel_code) {
        propertyMappings.push({
          concigoPropertyId: cfg.property_id,
          apaleoHotelCode: cfg.pms_hotel_code,
        })
      }
    }
  }

  if (!propertyMappings.length) {
    propertyMappings.push({
      concigoPropertyId: 'b0000001-0000-0000-0000-000000000001',
      apaleoHotelCode: row.property_id === 'ZIKG' ? 'BER' : row.property_id,
    })
  }

  let totalFetched = 0
  let totalSynced = 0
  let totalErrors = 0

  for (const mapping of propertyMappings) {
    // Fetch active/upcoming reservations
    const fetchRes = await fetchReservations(supabase, row, token, mapping.apaleoHotelCode)
    token = fetchRes.token
    const reservations = fetchRes.reservations
    totalFetched += reservations.length
    console.log(`[pms-sync-cron] Property ${mapping.apaleoHotelCode}: fetched ${reservations.length} reservations`)

    // Process reservations in batches of 5 to avoid connection bottlenecks
    const BATCH_SIZE = 5
    for (let i = 0; i < reservations.length; i += BATCH_SIZE) {
      const batch = reservations.slice(i, i + BATCH_SIZE)
      const results = await Promise.allSettled(
        batch.map((res) => ingestReservation(supabase, mapping.concigoPropertyId, res, token))
      )
      for (const r of results) {
        if (r.status === 'fulfilled') totalSynced++
        else {
          console.error('[pms-sync-cron] Ingest error:', r.reason)
          totalErrors++
        }
      }
    }
  }

  return { fetched: totalFetched, synced: totalSynced, errors: totalErrors }
}

async function fetchReservations(
  supabase: ReturnType<typeof createClient>,
  row: Record<string, string>,
  initialToken: string,
  propertyCode: string
): Promise<{ reservations: Record<string, unknown>[]; token: string }> {
  let currentToken = initialToken
  const statuses = ['Confirmed', 'InHouse', 'Reserved', 'Canceled']
  const allReservations: Record<string, unknown>[] = []

  for (const status of statuses) {
    try {
      const params = new URLSearchParams({
        propertyId: propertyCode,
        status: status,
        pageSize: '50',
      })

      let resp = await fetch(`${APALEO_BASE}/booking/v1/reservations?${params}`, {
        headers: { Authorization: `Bearer ${currentToken}` },
      })

      if (resp.status === 401) {
        console.warn('[pms-sync-cron] Got 401, refreshing token...')
        currentToken = await getValidToken(supabase, row, true)
        resp = await fetch(`${APALEO_BASE}/booking/v1/reservations?${params}`, {
          headers: { Authorization: `Bearer ${currentToken}` },
        })
      }

      if (resp.ok) {
        const data = await resp.json()
        const page = (data.reservations ?? []) as Record<string, unknown>[]
        allReservations.push(...page)
      } else {
        console.warn(`[pms-sync-cron] Failed to fetch ${status} reservations: ${resp.status}`)
      }
    } catch (e) {
      console.warn(`[pms-sync-cron] Error fetching ${status}:`, e)
    }
  }

  return { reservations: allReservations, token: currentToken }
}

function normalizePhone(raw: string): string {
  const stripped = raw.replace(/[\s\-()]/g, '')
  if (stripped.startsWith('+')) return stripped
  const digits = stripped.replace(/\D/g, '')
  if (digits.length === 10) return `+91${digits}`
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`
  return stripped
}

async function resolveOrCreateUser(supabase: ReturnType<typeof createClient>, guest: Record<string, unknown>): Promise<string | null> {
  try {
    const rawPhone = ((guest.phone as string) ?? '').trim()
    const email = ((guest.email as string) ?? '').trim()
    const firstName = ((guest.firstName as string) ?? '').trim()
    const lastName = ((guest.lastName as string) ?? '').trim()
    const fullName = [firstName, lastName].filter(Boolean).join(' ') || 'Guest'
    const phone = normalizePhone(rawPhone)

    // Single unified query to check existing user
    if (phone || email) {
      let query = supabase.from('users').select('user_id').eq('status', 'active').is('deleted_at', null)
      if (phone && email) {
        query = query.or(`mobile_no.eq.${phone},email.ilike.${email}`)
      } else if (phone) {
        query = query.eq('mobile_no', phone)
      } else if (email) {
        query = query.ilike('email', email)
      }

      const { data: users } = await query.limit(1)
      if (users?.length) return users[0].user_id as string
    }

    // Create new guest user profile
    const fallbackPhone = phone || `+9199${Date.now().toString().slice(5)}`
    const { data: newUser, error } = await supabase
      .from('users')
      .insert({
        name: fullName,
        mobile_no: fallbackPhone,
        email: email || null,
        status: 'active',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select('user_id').single()
    if (error) { console.error('[pms-sync-cron] Create user error:', error); return null }
    return newUser.user_id as string
  } catch (err) {
    console.error('[pms-sync-cron] resolveOrCreateUser error:', err)
    return null
  }
}

async function ingestReservation(
  supabase: ReturnType<typeof createClient>,
  concigoPropertyId: string,
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
  if (status === 'Canceled' || status === 'CheckedOut' || status === 'NoShow') stayStatus = 'Ended'
  else if (status === 'InHouse') stayStatus = 'Active'

  if (stayStatus === 'Ended') {
    if (resId) {
      const pmsTag = `PMS:${resId}`
      const { data: linkedCr } = await supabase
        .from('checkin_requests')
        .select('stay_id, stay:stay_id(status, stay_rooms(room_id))')
        .eq('remark', pmsTag)
        .limit(1)

      if (linkedCr?.length && linkedCr[0].stay_id) {
        const stayIdToClose = linkedCr[0].stay_id as string
        const stayObj = linkedCr[0].stay as Record<string, unknown> | null
        const currentStatus = stayObj?.status as string | undefined

        if (currentStatus && currentStatus !== 'Ended') {
          console.log(`[pms-sync-cron] Reservation ${resId} is ${status} in Apaleo. Closing stay ${stayIdToClose}...`)
          await supabase.from('stay').update({ status: 'Ended', updated_at: new Date().toISOString() }).eq('stay_id', stayIdToClose)
          await supabase.from('stay_guests').update({ status: 'Ended', updated_at: new Date().toISOString() }).eq('stay_id', stayIdToClose)

          const sRooms = (stayObj?.stay_rooms as Record<string, unknown>[]) ?? []
          for (const sr of sRooms) {
            const rId = sr.room_id as string
            if (rId) {
              await supabase.from('rooms').update({ is_booked: false, updated_at: new Date().toISOString() }).eq('room_id', rId)
            }
          }
        }

        // Settle folio charges for ended stay
        if (token) {
          await syncFolioCharges(supabase, concigoPropertyId, stayIdToClose, '', assignedRoom ?? '', resId, token, 'Ended')
        }
      }
    }
    return
  }

  const pmsTag = `PMS:${resId}`
  const guestUserId = await resolveOrCreateUser(supabase, guest)

  // 1. Check if PMS reservation is already linked to a stay via checkin_requests.remark
  let stayId: string | null = null
  if (resId) {
    const { data: linkedCr } = await supabase
      .from('checkin_requests').select('stay_id, stay(status)')
      .eq('remark', pmsTag).limit(1)
    if (linkedCr?.length) {
      const existingStatus = (linkedCr[0].stay as Record<string, unknown>)?.status as string
      if (existingStatus === 'Ended') return
      stayId = linkedCr[0].stay_id as string
    }
  }

  // 2. Check for existing stay by guest + check_in_date
  if (!stayId && guestUserId) {
    const { data: existingStay } = await supabase
      .from('stay').select('stay_id, status')
      .eq('hotel_id', concigoPropertyId).eq('check_in_date', checkInStr)
      .eq('main_user_id', guestUserId).neq('status', 'Ended').limit(1)
    if (existingStay?.length) stayId = existingStay[0].stay_id as string
  }

  if (stayId) {
    const { data: curr } = await supabase.from('stay').select('status').eq('stay_id', stayId).maybeSingle()
    const effectiveStatus = (curr?.status === 'Active' && stayStatus !== 'Ended') ? 'Active' : stayStatus
    await supabase.from('stay').update({
      check_out_date: checkOutStr,
      status: effectiveStatus,
      updated_at: new Date().toISOString(),
      ...(guestUserId ? { main_user_id: guestUserId } : {}),
    }).eq('stay_id', stayId)
  } else {
    const { data: newStay, error: stayErr } = await supabase.from('stay')
      .insert({
        hotel_id: concigoPropertyId,
        check_in_date: checkInStr,
        check_out_date: checkOutStr,
        status: stayStatus,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        ...(guestUserId ? { main_user_id: guestUserId } : {})
      })
      .select('stay_id').single()
    if (stayErr) throw stayErr
    stayId = newStay.stay_id as string
  }

  // Ensure stay_guests entry
  if (guestUserId && stayId) {
    const { data: existingGuests } = await supabase
      .from('stay_guests')
      .select('id')
      .eq('stay_id', stayId)
      .eq('user_id', guestUserId)
      .limit(1)
    if (!existingGuests?.length) {
      await supabase.from('stay_guests').insert({
        stay_id: stayId,
        user_id: guestUserId,
        status: 'approved',
      })
    }
  }

  // Ensure checkin_requests row with PMS tag
  if (resId && stayId) {
    const { data: existingCr } = await supabase.from('checkin_requests').select('id, remark').eq('stay_id', stayId).limit(1)
    if (existingCr?.length) {
      if (existingCr[0].remark !== pmsTag) {
        await supabase.from('checkin_requests').update({ remark: pmsTag, updated_at: new Date().toISOString() }).eq('id', existingCr[0].id)
      }
    } else if (guestUserId) {
      const code = String(1000 + (Date.now() % 9000))
      await supabase.from('checkin_requests').insert({
        stay_id: stayId,
        main_user_id: guestUserId,
        status: stayStatus === 'Active' ? 'approved' : 'pending',
        checkin_code: code,
        remark: pmsTag,
        submitted_req: [],
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
    }
  }

  // Link room if assigned
  if (assignedRoom && stayId) {
    const { data: roomRows } = await supabase.from('rooms')
      .select('room_id').eq('property_id', concigoPropertyId).eq('room_number', assignedRoom).limit(1)
    let roomId: string
    if (roomRows?.length) {
      roomId = roomRows[0].room_id as string
    } else {
      const { data: newRoom } = await supabase.from('rooms')
        .insert({
          property_id: concigoPropertyId,
          room_number: assignedRoom,
          is_active: true,
          is_booked: stayStatus === 'Active',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .select('room_id').single()
      if (!newRoom) return
      roomId = newRoom.room_id as string
    }

    const { data: existingSr } = await supabase
      .from('stay_rooms')
      .select('id')
      .eq('stay_id', stayId)
      .eq('room_id', roomId)
      .limit(1)
    if (!existingSr?.length) {
      await supabase.from('stay_rooms').insert({ stay_id: stayId, room_id: roomId })
    }

    if (stayStatus === 'Active') {
      await supabase.from('rooms').update({ is_booked: true, updated_at: new Date().toISOString() }).eq('room_id', roomId)
    }
  }

  // 4. Sync Folio Charges from Apaleo into service_bills
  if (stayId && token) {
    try {
      await syncFolioCharges(
        supabase,
        concigoPropertyId,
        stayId,
        guestUserId ?? '',
        assignedRoom ?? '',
        resId,
        token,
        stayStatus
      )
    } catch (folioErr) {
      console.warn(`[pms-sync-cron] Folio sync error for ${resId}:`, folioErr)
    }
  }

  console.log(`[pms-sync-cron] Ingested ${resId} -> stay=${stayId} status=${stayStatus}`)
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
    console.warn(`[pms-sync-cron] Cannot sync folio for stay ${stayId}: no user_id available`)
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
    console.warn(`[pms-sync-cron] Failed to fetch folios for ${resId}: ${foliosResp.status}`)
    return
  }

  const foliosData = await foliosResp.json()
  const folios = (foliosData.folios ?? []) as Record<string, unknown>[]
  if (!folios.length) return

  for (const folio of folios) {
    if (folio.isEmpty === true) continue

    const folioId = folio.id as string
    const folioStatus = (folio.status as string) ?? 'Open'
    const balanceObj = (folio.balance as Record<string, unknown>) ?? {}
    const rawBalance = (balanceObj.amount as number) ?? 0

    // In Apaleo: negative balance (e.g. -138.00) means guest owes money.
    // Zero or positive means settled.
    const isSettled = rawBalance >= -0.01 || folioStatus === 'Closed' || stayStatus === 'Ended'

    const detResp = await fetch(`${APALEO_BASE}/finance/v1/folios/${encodeURIComponent(folioId)}`, {
      headers: { Authorization: `Bearer ${token}` },
    })

    if (!detResp.ok) {
      console.warn(`[pms-sync-cron] Failed to fetch folio details ${folioId}: ${detResp.status}`)
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

function formatChargeDate(isoDate?: string): string {
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
          // If this charge was refunded/cancelled by an allowance in Apaleo, remove it from service_bills
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
          console.error(`[pms-sync-cron] Error upserting service_bill ${billId}:`, upsertErr)
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

