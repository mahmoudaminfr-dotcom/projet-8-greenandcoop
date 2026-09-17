{{ config(
    materialized='table',
    indexes=[
      {'columns': ['reading_id'], 'unique': true},
      {'columns': ['station_id']},
      {'columns': ['recorded_at_utc']},
      {'columns': ['station_id', 'recorded_at_utc']}
    ]
) }}

with infoclimat_data as (
    select
        md5(station_id || '_' || recorded_at_utc::text) as reading_id,
        station_id,
        recorded_at_utc,
        temperature_celsius,
        dew_point_celsius,
        humidity_percent,
        pressure_hpa,
        wind_speed_kmh,
        wind_gust_kmh,
        wind_direction_deg,
        null::text as wind_direction_cardinal,
        precip_1h_mm,
        precip_3h_mm,
        null::numeric as precipitation_rate_mm_h,
        null::numeric as precipitation_accum_mm,
        visibility_km,
        cloud_cover_oktas,
        weather_code_omm,
        null::numeric as uv_index,
        null::numeric as solar_radiation_w_m2,
        'infoclimat' as data_source
    from {{ ref('int_infoclimat_standardized') }}
),

wu_data as (
    select
        md5(station_id || '_' || recorded_at_utc::text) as reading_id,
        station_id,
        recorded_at_utc,
        temperature_celsius,
        dew_point_celsius,
        humidity_percent,
        pressure_hpa,
        wind_speed_kmh,
        wind_gust_kmh,
        null::numeric as wind_direction_deg,
        wind_direction_cardinal,
        null::numeric as precip_1h_mm,
        null::numeric as precip_3h_mm,
        precipitation_rate_mm_h,
        precipitation_accum_mm,
        null::numeric as visibility_km,
        null::numeric as cloud_cover_oktas,
        null::integer as weather_code_omm,
        uv_index,
        solar_radiation_w_m2,
        'weather_underground' as data_source
    from {{ ref('int_wu_readings_standardized') }}
)

select * from infoclimat_data
union all
select * from wu_data