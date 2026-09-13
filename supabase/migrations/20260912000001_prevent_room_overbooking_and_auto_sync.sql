-- Migration: Prevent Room Overbooking and Synchronize Stay Expiration
-- Creates an overlap prevention trigger on stay_rooms, availability check function, and stay expiration sync.

-- ── 1. Function & Trigger: Prevent Double-Booking Overlapping Dates on stay_rooms ──
CREATE OR REPLACE FUNCTION public.check_room_overlap_before_assignment()
RETURNS TRIGGER AS $$
DECLARE
    v_hotel_id UUID;
    v_check_in DATE;
    v_check_out DATE;
    v_conflicting_stay_id UUID;
    v_conflicting_guest_name TEXT;
    v_conflicting_check_in DATE;
    v_conflicting_check_out DATE;
BEGIN
    -- Fetch the check-in and check-out dates of the stay being assigned
    SELECT hotel_id, check_in_date, check_out_date
    INTO v_hotel_id, v_check_in, v_check_out
    FROM public.stay
    WHERE stay_id = NEW.stay_id;

    -- If stay not found or dates are null, permit insertion
    IF v_check_in IS NULL OR v_check_out IS NULL THEN
        RETURN NEW;
    END IF;

    -- Check for any overlapping stay in the same room that is 'Active' or 'Upcoming'
    SELECT s.stay_id, COALESCE(u.name, 'Another Guest'), s.check_in_date, s.check_out_date
    INTO v_conflicting_stay_id, v_conflicting_guest_name, v_conflicting_check_in, v_conflicting_check_out
    FROM public.stay_rooms sr
    JOIN public.stay s ON s.stay_id = sr.stay_id
    LEFT JOIN public.users u ON u.user_id = s.main_user_id
    WHERE sr.room_id = NEW.room_id
      AND sr.stay_id != NEW.stay_id
      AND s.status IN ('Active', 'Upcoming')
      AND (s.check_in_date < v_check_out AND s.check_out_date > v_check_in)
      AND s.deleted_at IS NULL
    LIMIT 1;

    IF v_conflicting_stay_id IS NOT NULL THEN
        RAISE EXCEPTION 'ROOM_DOUBLE_BOOKING_PREVENTED: Room is already booked by % from % to % (Stay ID: %)',
            v_conflicting_guest_name, v_conflicting_check_in, v_conflicting_check_out, v_conflicting_stay_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_room_overlap ON public.stay_rooms;
CREATE TRIGGER trg_check_room_overlap
BEFORE INSERT OR UPDATE ON public.stay_rooms
FOR EACH ROW
EXECUTE FUNCTION public.check_room_overlap_before_assignment();


-- ── 2. RPC Function: Check Room Availability for a Date Range ──────────────
CREATE OR REPLACE FUNCTION public.check_room_available(
    p_room_id UUID,
    p_check_in DATE,
    p_check_out DATE,
    p_exclude_stay_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN NOT EXISTS (
        SELECT 1
        FROM public.stay_rooms sr
        JOIN public.stay s ON s.stay_id = sr.stay_id
        WHERE sr.room_id = p_room_id
          AND (p_exclude_stay_id IS NULL OR sr.stay_id != p_exclude_stay_id)
          AND s.status IN ('Active', 'Upcoming')
          AND (s.check_in_date < p_check_out AND s.check_out_date > p_check_in)
          AND s.deleted_at IS NULL
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ── 3. RPC Function: Automatic Stay Expiration and Room Occupancy Sync ──────
CREATE OR REPLACE FUNCTION public.sync_expired_stays_and_rooms()
RETURNS JSONB AS $$
DECLARE
    v_expired_count INT := 0;
    v_released_rooms INT := 0;
BEGIN
    -- 1. Mark any active stay whose check_out_date is in the past as Ended
    WITH updated_stays AS (
        UPDATE public.stay
        SET status = 'Ended', updated_at = NOW()
        WHERE status = 'Active'
          AND check_out_date < CURRENT_DATE
        RETURNING stay_id
    )
    SELECT COUNT(*) INTO v_expired_count FROM updated_stays;

    -- 2. Also sync stay_guests for ended stays
    UPDATE public.stay_guests sg
    SET status = 'Ended'
    FROM public.stay s
    WHERE sg.stay_id = s.stay_id
      AND s.status = 'Ended'
      AND (sg.status IS NULL OR sg.status != 'Ended');

    -- 3. Synchronize rooms.is_booked based on genuine live occupancy today
    -- A room is booked only if an Active stay occupies it today
    UPDATE public.rooms r
    SET is_booked = EXISTS (
        SELECT 1
        FROM public.stay_rooms sr
        JOIN public.stay s ON s.stay_id = sr.stay_id
        WHERE sr.room_id = r.room_id
          AND s.status = 'Active'
          AND CURRENT_DATE >= s.check_in_date
          AND CURRENT_DATE < s.check_out_date
          AND s.deleted_at IS NULL
    ),
    updated_at = NOW();

    GET DIAGNOSTICS v_released_rooms = ROW_COUNT;

    RETURN jsonb_build_object(
        'expired_stays_count', v_expired_count,
        'rooms_synced', v_released_rooms,
        'synced_at', NOW()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execution permissions on RPC functions to authenticated & anon roles
GRANT EXECUTE ON FUNCTION public.check_room_available(UUID, DATE, DATE, UUID) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sync_expired_stays_and_rooms() TO anon, authenticated, service_role;
