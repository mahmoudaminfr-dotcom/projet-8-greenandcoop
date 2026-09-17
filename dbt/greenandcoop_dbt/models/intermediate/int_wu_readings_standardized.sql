{{
    config(
        materialized='view'
    )
}}

with unioned_wu as (
    select
        station_id,
        recorded_date_raw,
        recorded_time_raw,
        temperature_raw,
        dew_point_raw,
        humidity_raw,
        wind_direction_raw,
        wind_speed_raw,
        wind_gust_raw,
        pressure_raw,
        precip_rate_raw,
        precip_accum_raw,
        uv_raw,
        solar_radiation_raw
    from {{ ref('stg_wu_ichtegem') }}

    union all

    select
        station_id,
        recorded_date_raw,
        recorded_time_raw,
        temperature_raw,
        dew_point_raw,
        humidity_raw,
        wind_direction_raw,
        wind_speed_raw,
        wind_gust_raw,
        pressure_raw,
        precip_rate_raw,
        precip_accum_raw,
        uv_raw,
        solar_radiation_raw
    from {{ ref('stg_wu_la_madeleine') }}
),

standardized as (
    select
        station_id,
        -- Construction du timestamp UTC (heure locale de la station supposée Europe/Paris, convertie en UTC)
        timezone('UTC', (recorded_date_raw || ' ' || recorded_time_raw)::timestamp without time zone) as recorded_at_utc,
        
        -- Température & Point de rosée : (°F - 32) * 5/9 -> °C
        round(((regexp_replace(temperature_raw::text, '[^\d.-]', '', 'g')::numeric - 32) * 5.0 / 9.0), 2) as temperature_celsius,
        round(((regexp_replace(dew_point_raw::text, '[^\d.-]', '', 'g')::numeric - 32) * 5.0 / 9.0), 2) as dew_point_celsius,
        
        -- Humidité : conversion directe % en numérique
        regexp_replace(humidity_raw::text, '[^\d.-]', '', 'g')::numeric as humidity_percent,

        -- Direction du vent (ex: N, NNE, SW)
        trim(wind_direction_raw::text) as wind_direction_cardinal,
        
        -- Vitesse & Rafales du vent : mph * 1.609344 -> km/h
        round((regexp_replace(wind_speed_raw::text, '[^\d.-]', '', 'g')::numeric * 1.609344), 2) as wind_speed_kmh,
        round((regexp_replace(wind_gust_raw::text, '[^\d.-]', '', 'g')::numeric * 1.609344), 2) as wind_gust_kmh,
        
        -- Pression atmosphérique : inHg * 33.863886666667 -> hPa
        round((regexp_replace(pressure_raw::text, '[^\d.-]', '', 'g')::numeric * 33.863886666667), 2) as pressure_hpa,
        
        -- Précipitations (taux et cumul) : in * 25.4 -> mm
        round((regexp_replace(precip_rate_raw::text, '[^\d.-]', '', 'g')::numeric * 25.4), 2) as precipitation_rate_mm_h,
        round((regexp_replace(precip_accum_raw::text, '[^\d.-]', '', 'g')::numeric * 25.4), 2) as precipitation_accum_mm,
        
        -- UV et Radiation solaire
        nullif(regexp_replace(uv_raw::text, '[^\d.-]', '', 'g'), '')::numeric as uv_index,
        nullif(regexp_replace(solar_radiation_raw::text, '[^\d.-]', '', 'g'), '')::numeric as solar_radiation_w_m2

    from unioned_wu
)

select * from standardized