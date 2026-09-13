-- ============================================================
-- Migration: 20260911000001_seed_royal_orchid_amenities
-- Seeds amenities for Royal Orchid Palace (6f28d6a7-57d1-4b65-9a75-3f89e0d11001)
-- and updates RLS to allow anon / public SELECT of active amenities.
-- ============================================================

-- 1. Update SELECT policy to allow public/anon & authenticated access
DROP POLICY IF EXISTS "amenities_select_authenticated" ON public.amenities;
DROP POLICY IF EXISTS "amenities_select_public" ON public.amenities;

CREATE POLICY "amenities_select_public"
    ON public.amenities
    FOR SELECT
    TO anon, authenticated
    USING (is_active = true AND deleted_at IS NULL);

-- 2. Seed amenities for Royal Orchid Palace (property_id: 6f28d6a7-57d1-4b65-9a75-3f89e0d11001)
INSERT INTO public.amenities (property_id, name, description, images, is_active)
SELECT
    '6f28d6a7-57d1-4b65-9a75-3f89e0d11001'::uuid,
    v.name,
    v.description,
    v.images::jsonb,
    true
FROM (VALUES
    (
        'Free WiFi',
        E'Complimentary high-speed WiFi available throughout the palace grounds and guest suites.\n• Available 24/7\n• High speed fiber connection\n• Secure network access',
        '["https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=600&q=80"]'
    ),
    (
        'Swimming Pool',
        E'Grand royal swimming pool with sunken lounge and poolside bar.\n• Open 6:00 AM – 10:00 PM\n• Plush loungers & cabanas available\n• Lifeguard on duty',
        '["https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=600&q=80"]'
    ),
    (
        'Ayurvedic Spa',
        E'Holistic wellness treatments, aromatic therapies, and rejuvenation massages.\n• Open 9:00 AM – 9:00 PM\n• Certified therapists\n• Private steam rooms',
        '["https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=600&q=80"]'
    ),
    (
        'Fitness Center',
        E'State-of-the-art gymnasium with personal fitness guidance and cardio equipment.\n• Open 24 Hours\n• Steam & sauna facilities\n• Towels & refreshments provided',
        '["https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80"]'
    ),
    (
        'Fine Dining',
        E'Curated royal culinary experiences, alfresco seating, and sommelier selections.\n• Breakfast, lunch & dinner\n• 24/7 In-room dining service\n• Multi-cuisine menu',
        '["https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80"]'
    ),
    (
        'Valet Parking',
        E'Complimentary premium valet assistance and secure covered guest parking.\n• 24/7 Attended valet service\n• EV charging stations available\n• CCTV monitored',
        '["https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=600&q=80"]'
    )
) AS v(name, description, images)
WHERE NOT EXISTS (
    SELECT 1 FROM public.amenities
    WHERE property_id = '6f28d6a7-57d1-4b65-9a75-3f89e0d11001'::uuid
);
