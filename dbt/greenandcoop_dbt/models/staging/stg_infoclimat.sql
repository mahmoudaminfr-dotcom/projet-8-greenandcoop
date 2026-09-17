with raw_source as (

    select
        _airbyte_raw_id as airbyte_id,
        _airbyte_extracted_at as ingested_at,
        hourly
    from {{ source('raw', 'infoclimat_raw') }}

),

stations_expanded as (

    select
        airbyte_id,
        ingested_at,
        station_key,
        station_data
    from raw_source,
    lateral jsonb_each(hourly) as kv(station_key, station_data)
    where station_key != '_params'

),

readings_unnested as (

    select
        airbyte_id,
        ingested_at,
        station_key as station_id,
        jsonb_array_elements(station_data) as reading
    from stations_expanded

),

renamed as (

    select
        airbyte_id,
        ingested_at,
        station_id,
        reading ->> 'dh_utc' as recorded_at_utc_raw,
        reading ->> 'temperature' as temperature_raw,
        reading ->> 'point_de_rosee' as dew_point_raw,
        reading ->> 'humidite' as humidity_raw,
        reading ->> 'vent_direction' as wind_direction_raw,
        reading ->> 'vent_moyen' as wind_speed_raw,
        reading ->> 'vent_rafales' as wind_gust_raw,
        reading ->> 'pression' as pressure_raw,
        reading ->> 'pluie_1h' as precip_1h_raw,
        reading ->> 'pluie_3h' as precip_3h_raw,
        reading ->> 'visibilite' as visibility_raw,
        reading ->> 'nebulosite' as cloud_cover_raw,
        reading ->> 'temps_omm' as weather_code_raw
    from readings_unnested

)

select * from renamed