{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ ref('stg_infoclimat') }}
),

standardized as (
    select
        station_id,
        -- L'horodatage dh_utc est déjà au format ISO UTC (ex: '2024-10-01 00:00:00')
        recorded_at_utc_raw::timestamp with time zone as recorded_at_utc,
        
        -- InfoClimat fournit déjà les données en unités métriques standard (°C, hPa, km/h, mm)
        -- Transtypage numérique sécurisé contre d'éventuelles chaînes vides
        nullif(regexp_replace(temperature_raw::text, '[^\d.-]', '', 'g'), '')::numeric as temperature_celsius,
        nullif(regexp_replace(dew_point_raw::text, '[^\d.-]', '', 'g'), '')::numeric as dew_point_celsius,
        nullif(regexp_replace(humidity_raw::text, '[^\d.-]', '', 'g'), '')::numeric as humidity_percent,
        nullif(regexp_replace(wind_direction_raw::text, '[^\d.-]', '', 'g'), '')::numeric as wind_direction_deg,
        nullif(regexp_replace(wind_speed_raw::text, '[^\d.-]', '', 'g'), '')::numeric as wind_speed_kmh,
        nullif(regexp_replace(wind_gust_raw::text, '[^\d.-]', '', 'g'), '')::numeric as wind_gust_kmh,
        nullif(regexp_replace(pressure_raw::text, '[^\d.-]', '', 'g'), '')::numeric as pressure_hpa,
        nullif(regexp_replace(precip_1h_raw::text, '[^\d.-]', '', 'g'), '')::numeric as precip_1h_mm,
        nullif(regexp_replace(precip_3h_raw::text, '[^\d.-]', '', 'g'), '')::numeric as precip_3h_mm,
        nullif(regexp_replace(visibility_raw::text, '[^\d.-]', '', 'g'), '')::numeric as visibility_km,
        nullif(regexp_replace(cloud_cover_raw::text, '[^\d.-]', '', 'g'), '')::numeric as cloud_cover_oktas,
        nullif(regexp_replace(weather_code_raw::text, '[^\d.-]', '', 'g'), '')::integer as weather_code_omm
    from source
)

select * from standardized