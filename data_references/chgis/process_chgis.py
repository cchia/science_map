import sys
import argparse
import geopandas as gpd
from shapely.geometry import shape
import os

def process_shapefile(input_shp, output_geojson, target_year=None, simplify_tolerance=0.01):
    print(f"Loading shapefile: {input_shp}...")
    try:
        # Load the shapefile
        gdf = gpd.read_file(input_shp)
        
        # If it's a Time Series shapefile, it usually has BEG_YR and END_YR
        if target_year is not None:
            print(f"Filtering features active in year {target_year}...")
            # Check for standard CHGIS time series fields
            if 'BEG_YR' in gdf.columns and 'END_YR' in gdf.columns:
                gdf = gdf[(gdf['BEG_YR'] <= target_year) & (gdf['END_YR'] >= target_year)]
            elif 'SYS_MOD_YR' in gdf.columns: # Sometimes there are different time fields
                 print("Warning: BEG_YR/END_YR not found. Please verify the shapefile schema.")
            else:
                 print("Assuming this is a Time Slice shapefile (like 1820). No year filtering applied.")
        
        if gdf.empty:
            print("No features found matching the criteria.")
            return

        print(f"Found {len(gdf)} features. Dissolving into a single boundary...")
        # Add a dummy column to dissolve all geometries into one
        gdf['dissolve_field'] = 1
        dissolved = gdf.dissolve(by='dissolve_field')

        print(f"Simplifying geometry with tolerance {simplify_tolerance} degrees...")
        # Simplify geometry to reduce file size (0.01 to 0.05 is usually good for country level)
        # Note: tolerance is in the same units as the coordinate reference system. 
        # CHGIS is usually WGS84 (degrees). 0.01 degree is ~1km.
        simplified = dissolved.simplify(tolerance=simplify_tolerance, preserve_topology=True)
        
        # Create a new GeoDataFrame with the simplified geometry
        out_gdf = gpd.GeoDataFrame(geometry=simplified, crs=gdf.crs)
        
        # Add properties that our app expects
        dynasty_name = f"CHGIS_Data_Year_{target_year if target_year else 'Slice'}"
        out_gdf['name'] = dynasty_name
        
        print(f"Exporting to {output_geojson}...")
        # Export to GeoJSON
        out_gdf.to_file(output_geojson, driver='GeoJSON')
        
        file_size = os.path.getsize(output_geojson) / (1024 * 1024)
        print(f"Success! GeoJSON saved to {output_geojson} (Size: {file_size:.2f} MB)")

    except Exception as e:
        print(f"Error processing shapefile: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process CHGIS Shapefiles into simplified GeoJSON.")
    parser.add_argument("input_shp", help="Path to the input .shp file")
    parser.add_argument("output_geojson", help="Path to the output .geojson file")
    parser.add_argument("--year", type=int, default=None, help="Target year to extract (for Time Series data)")
    parser.add_argument("--simplify", type=float, default=0.01, help="Simplification tolerance (degrees, default: 0.01)")
    
    args = parser.parse_args()
    
    process_shapefile(args.input_shp, args.output_geojson, args.year, args.simplify)
