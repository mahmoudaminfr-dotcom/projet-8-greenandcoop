{{ config(
    materialized='table',
    indexes=[
      {'columns': ['station_id'], 'unique': true}
    ]
) }}

WITH stations_infoclimat AS (
    SELECT DISTINCT
        station_id,
        CASE 
            WHEN station_id = '00052' THEN 'Armentières'
            WHEN station_id = '000R5' THEN 'Bergues'
            WHEN station_id = '07015' THEN 'Lille-Lesquin'
            WHEN station_id = 'STATIC0010' THEN 'Hazebrouck'
            ELSE 'Station InfoClimat ' || station_id
        END AS station_name,
        'InfoClimat' AS source_network
    FROM {{ ref('int_infoclimat_standardized') }}
),

stations_wu AS (
    SELECT DISTINCT
        station_id,
        CASE 
            WHEN station_id = 'ichtegem' THEN 'Ichtegem'
            WHEN station_id = 'la_madeleine' THEN 'La Madeleine'
            ELSE station_id
        END AS station_name,
        'Weather Underground' AS source_network
    FROM {{ ref('int_wu_readings_standardized') }}
)

SELECT 
    station_id,
    station_name,
    source_network
FROM stations_infoclimat

UNION ALL

SELECT 
    station_id,
    station_name,
    source_network
FROM stations_wu