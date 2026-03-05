#!/usr/bin/env python3
# /// script
# dependencies = [
#     "neo4j",
#     "pandas",
# ]
# requires-python = ">=3.11"
# ///

import json
import pandas as pd
from neo4j import GraphDatabase
from neo4j.time import DateTime, Date, Time, Duration
from datetime import datetime
import os
import sys
import threading
import queue
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import logging
import gzip
import pickle
import argparse

class Neo4jJSONEncoder(json.JSONEncoder):
    """Custom JSON encoder for Neo4j types"""
    def default(self, o):
        if isinstance(o, DateTime):
            return o.isoformat()
        elif isinstance(o, Date):
            return o.isoformat()
        elif isinstance(o, Time):
            return o.isoformat()
        elif isinstance(o, Duration):
            return str(o)
        return super().default(o)

class HighPerformanceNeo4jExporter:
    def __init__(self, uri: str, username: str, password: str, database: str = "neo4j", 
                 batch_size: int = 10000, max_workers: int = 4, compress_output: bool = True):
        self.driver = GraphDatabase.driver(uri, auth=(username, password), 
                                         max_connection_pool_size=50)
        self.database = database
        self.batch_size = batch_size
        self.max_workers = max_workers
        self.compress_output = compress_output
        self.export_dir = "neo4j_export"
        
      
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(f"{self.export_dir}/export.log"),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
      
    def close(self):
        self.driver.close()
  
    def run_query_with_retry(self, query: str, parameters: dict | None = None, max_retries: int = 3):
        """Execute query with retry logic"""
        for attempt in range(max_retries):
            try:
                with self.driver.session(database=self.database) as session:
                    result = session.run(query, parameters)
                    return [record.data() for record in result]
            except Exception as e:
                if attempt == max_retries - 1:
                    raise
                self.logger.warning(f"Query failed (attempt {attempt + 1}): {str(e)}")
                time.sleep(2 ** attempt)  # Exponential backoff
  
    def get_total_counts(self) -> tuple[int, int]:
        """Get total counts efficiently"""
        self.logger.info("Getting total counts...")
      
        # Use parallel queries for counts
        with ThreadPoolExecutor(max_workers=2) as executor:
            node_future = executor.submit(self.run_query_with_retry, "MATCH (n) RETURN count(n) as total")
            rel_future = executor.submit(self.run_query_with_retry, "MATCH ()-[r]->() RETURN count(r) as total")
          
            total_nodes = node_future.result()[0]['total']
            total_rels = rel_future.result()[0]['total']
      
        self.logger.info(f"Database contains {total_nodes:,} nodes and {total_rels:,} relationships")
        return total_nodes, total_rels
  
    def export_nodes_streaming(self) -> int:
        """Export nodes using streaming approach with ID-based pagination"""
        self.logger.info("Starting streaming node export...")
      
        # Get ID ranges for better pagination
        id_ranges = self.run_query_with_retry("""
            MATCH (n) 
            RETURN min(id(n)) as min_id, max(id(n)) as max_id
        """)[0]
      
        min_id = id_ranges['min_id']
        max_id = id_ranges['max_id']
      
        if min_id is None or max_id is None:
            self.logger.warning("No nodes found in database")
            return 0
      
        self.logger.info(f"Node ID range: {min_id} to {max_id}")
      
        # Create output files
        nodes_file = f"{self.export_dir}/nodes.jsonl"
        if self.compress_output:
            nodes_file += ".gz"
            file_handle = gzip.open(nodes_file, 'wt', encoding='utf-8')
        else:
            file_handle = open(nodes_file, 'w', encoding='utf-8')
      
        csv_file = f"{self.export_dir}/nodes.csv"
        csv_writer: pd.DataFrame | None = None
        csv_file_handle = None
      
        try:
            current_id = min_id
            total_exported = 0
          
            while current_id <= max_id:
                # Use ID-based pagination (more efficient than SKIP)
                batch = self.run_query_with_retry(f"""
                    MATCH (n) 
                    WHERE id(n) >= {current_id} AND id(n) < {current_id + self.batch_size}
                    RETURN 
                        id(n) as NodeId,
                        labels(n) as Labels,
                        properties(n) as Properties
                    ORDER BY id(n)
                """)
              
                if not batch:
                    current_id += self.batch_size
                    continue
              
                # Write to JSONL file (one JSON object per line)
                for node in batch:
                    self._write_json_line(file_handle, node)
              
                # Write to CSV (first batch creates headers)
                if csv_writer is None:
                    # Collect all possible property keys from first batch
                    all_props = set()
                    for node in batch:
                        if node['Properties']:
                            all_props.update(node['Properties'].keys())
                  
                    csv_columns = ['NodeId', 'Labels'] + sorted(list(all_props))
                    csv_file_handle = open(csv_file, 'w', newline='', encoding='utf-8')
                    csv_writer = pd.DataFrame(columns=csv_columns) # Just for type hint
                    csv_rows: list[dict] = []
              
                # Prepare CSV rows
                for node in batch:
                    row = {
                        'NodeId': node['NodeId'],
                        'Labels': '|'.join(node['Labels']) if node['Labels'] else '',
                    }
                    # Add all properties as separate columns
                    if node['Properties']:
                        row.update(node['Properties'])
                    csv_rows.append(row)
              
                # Write CSV batch
                if csv_rows:
                    batch_df = pd.DataFrame(csv_rows)
                    if total_exported == 0:
                        batch_df.to_csv(csv_file_handle, index=False)
                    else:
                        batch_df.to_csv(csv_file_handle, index=False, header=False)
                    csv_rows = []
              
                total_exported += len(batch)
                current_id = max([node['NodeId'] for node in batch]) + 1
              
                self.logger.info(f"Exported {total_exported:,} nodes...")
              
        finally:
            file_handle.close()
            if csv_file_handle:
                csv_file_handle.close()
      
        self.logger.info(f"✅ Node export completed: {total_exported:,} nodes")
        return total_exported
  
    def export_relationships_streaming(self) -> int:
        """Export relationships using streaming approach"""
        self.logger.info("Starting streaming relationship export...")
      
        # Get relationship ID ranges
        id_ranges = self.run_query_with_retry("""
            MATCH ()-[r]->() 
            RETURN min(id(r)) as min_id, max(id(r)) as max_id
        """)[0]
      
        min_id = id_ranges['min_id']
        max_id = id_ranges['max_id']
      
        if min_id is None or max_id is None:
            self.logger.warning("No relationships found in database")
            return 0
      
        self.logger.info(f"Relationship ID range: {min_id} to {max_id}")
      
        # Create output files
        rels_file = f"{self.export_dir}/relationships.jsonl"
        if self.compress_output:
            rels_file += ".gz"
            file_handle = gzip.open(rels_file, 'wt', encoding='utf-8')
        else:
            file_handle = open(rels_file, 'w', encoding='utf-8')
      
        csv_file = f"{self.export_dir}/relationships.csv"
        csv_file_handle = None
      
        try:
            current_id = min_id
            total_exported = 0
          
            while current_id <= max_id:
                batch = self.run_query_with_retry(f"""
                    MATCH (a)-[r]->(b) 
                    WHERE id(r) >= {current_id} AND id(r) < {current_id + self.batch_size}
                    RETURN 
                        id(r) as RelationshipId,
                        id(a) as FromNodeId,
                        labels(a) as FromNodeLabels,
                        type(r) as RelationshipType,
                        properties(r) as RelationshipProperties,
                        id(b) as ToNodeId,
                        labels(b) as ToNodeLabels
                    ORDER BY id(r)
                """)
              
                if not batch:
                    current_id += self.batch_size
                    continue
              
                # Write to JSONL
                for rel in batch:
                    self._write_json_line(file_handle, rel)
              
                # Write to CSV
                csv_rows: list[dict] = []
                for rel in batch:
                    row = {
                        'RelationshipId': rel['RelationshipId'],
                        'FromNodeId': rel['FromNodeId'],
                        'FromNodeLabels': '|'.join(rel['FromNodeLabels']) if rel['FromNodeLabels'] else '',
                        'RelationshipType': rel['RelationshipType'],
                        'ToNodeId': rel['ToNodeId'],
                        'ToNodeLabels': '|'.join(rel['ToNodeLabels']) if rel['ToNodeLabels'] else '',
                    }
                    if rel['RelationshipProperties']:
                        for key, value in rel['RelationshipProperties'].items():
                            row[f'rel_{key}'] = value
                    csv_rows.append(row)
              
                if csv_rows:
                    batch_df = pd.DataFrame(csv_rows)
                    if total_exported == 0:
                        batch_df.to_csv(csv_file, index=False)
                        csv_file_handle = open(csv_file, 'a', newline='')
                    else:
                        batch_df.to_csv(csv_file_handle, index=False, header=False)
              
                total_exported += len(batch)
                current_id = max([rel['RelationshipId'] for rel in batch]) + 1
              
                self.logger.info(f"Exported {total_exported:,} relationships...")
              
        finally:
            file_handle.close()
            if csv_file_handle:
                csv_file_handle.close()
      
        self.logger.info(f"✅ Relationship export completed: {total_exported:,} relationships")
        return total_exported
  
    def export_by_label_parallel(self) -> int:
        """Export nodes by label in parallel (alternative approach)"""
        self.logger.info("Starting parallel export by node labels...")
      
        # Get all labels
        labels = self.run_query_with_retry("CALL db.labels() YIELD label RETURN label")
        label_names = [record['label'] for record in labels]
      
        self.logger.info(f"Found {len(label_names)} node labels: {label_names}")
      
        def export_label(label: str) -> int:
            """Export nodes for a specific label"""
            self.logger.info(f"Exporting label: {label}")
          
            label_file = f"{self.export_dir}/nodes_{label}.jsonl"
            if self.compress_output:
                label_file += ".gz"
                file_handle = gzip.open(label_file, 'wt', encoding='utf-8')
            else:
                file_handle = open(label_file, 'w', encoding='utf-8')
          
            try:
                skip = 0
                total_for_label = 0
              
                while True:
                    batch = self.run_query_with_retry(f"""
                        MATCH (n:{label}) 
                        RETURN 
                            id(n) as NodeId,
                            labels(n) as Labels,
                            properties(n) as Properties
                        ORDER BY id(n)
                        SKIP {skip} LIMIT {self.batch_size}
                    """)
                  
                    if not batch:
                        break
                  
                    for node in batch:
                        self._write_json_line(file_handle, node)
                  
                    total_for_label += len(batch)
                    skip += self.batch_size
                  
                    if len(batch) < self.batch_size:
                        break
              
                self.logger.info(f"✅ Exported {total_for_label:,} nodes for label '{label}'")
                return total_for_label
              
            finally:
                file_handle.close()
      
        # Export labels in parallel
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            futures = {executor.submit(export_label, label): label for label in label_names}
          
            total_nodes = 0
            for future in as_completed(futures):
                label = futures[future]
                try:
                    count = future.result()
                    total_nodes += count
                except Exception as e:
                    self.logger.error(f"Failed to export label '{label}': {str(e)}")
      
        return total_nodes
  
    def export_database_stats(self):
        """Export database statistics and overview"""
        self.logger.info("📊 Exporting database statistics...")
      
        # Node counts by label
        node_stats = self.run_query_with_retry("""
            MATCH (n) 
            RETURN DISTINCT labels(n) as NodeLabels, count(n) as Count 
            ORDER BY Count DESC
        """)
      
        # Relationship counts by type
        rel_stats = self.run_query_with_retry("""
            MATCH ()-[r]->() 
            RETURN type(r) as RelationshipType, count(r) as Count 
            ORDER BY Count DESC
        """)
      
        # Total counts
        total_nodes = self.run_query_with_retry("MATCH (n) RETURN count(n) as total")[0]['total']
        total_rels = self.run_query_with_retry("MATCH ()-[r]->() RETURN count(r) as total")[0]['total']
      
        stats = {
            'database': self.database,
            'export_timestamp': datetime.now().isoformat(),
            'total_nodes': total_nodes,
            'total_relationships': total_rels,
            'node_labels': node_stats,
            'relationship_types': rel_stats
        }
      
        # Save to JSON
        with open(f"{self.export_dir}/database_stats.json", 'w') as f:
            json.dump(stats, f, indent=2, cls=Neo4jJSONEncoder)
      
        # Save to CSV
        pd.DataFrame(node_stats).to_csv(f"{self.export_dir}/node_counts.csv", index=False)
        pd.DataFrame(rel_stats).to_csv(f"{self.export_dir}/relationship_counts.csv", index=False)
      
        self.logger.info(f"✅ Database has {total_nodes} nodes and {total_rels} relationships")
        return stats
  
    def export_schema(self):
        """Export database schema information"""
        self.logger.info("📋 Exporting schema information...")
      
        # Get all labels
        labels = self.run_query_with_retry("CALL db.labels() YIELD label RETURN label")
      
        # Get all relationship types
        rel_types = self.run_query_with_retry("CALL db.relationshipTypes() YIELD relationshipType RETURN relationshipType")
      
        # Get property keys
        prop_keys = self.run_query_with_retry("CALL db.propertyKeys() YIELD propertyKey RETURN propertyKey")
      
        schema_info = {
            'labels': [record['label'] for record in labels],
            'relationship_types': [record['relationshipType'] for record in rel_types],
            'property_keys': [record['propertyKey'] for record in prop_keys]
        }
      
        # Try to get detailed schema (may not work in all Neo4j versions)
        try:
            node_schema = self.run_query_with_retry("""
                CALL db.schema.nodeTypeProperties() 
                YIELD nodeType, propertyName, propertyTypes, mandatory
                RETURN nodeType, propertyName, propertyTypes, mandatory
            """)
            schema_info['node_properties'] = node_schema
        except Exception as e:
            self.logger.warning(f"⚠️  Detailed node schema not available in this Neo4j version or query failed: {e}")
      
        try:
            rel_schema = self.run_query_with_retry("""
                CALL db.schema.relTypeProperties() 
                YIELD relType, propertyName, propertyTypes, mandatory
                RETURN relType, propertyName, propertyTypes, mandatory
            """)
            schema_info['relationship_properties'] = rel_schema
        except Exception as e:
            self.logger.warning(f"⚠️  Detailed relationship schema not available in this Neo4j version or query failed: {e}")
      
        # Save schema
        with open(f"{self.export_dir}/schema.json", 'w') as f:
            json.dump(schema_info, f, indent=2, cls=Neo4jJSONEncoder)
      
        return schema_info
  
    def estimate_export_time(self) -> float:
        """Estimate export time based on sample"""
        self.logger.info("Estimating export time...")
      
        # Sample 1000 nodes and time it
        start_time = time.time()
        sample = self.run_query_with_retry("""
            MATCH (n) 
            RETURN id(n), labels(n), properties(n)
            LIMIT 1000
        """)
        sample_time = time.time() - start_time
      
        total_nodes, total_rels = self.get_total_counts()
      
        # Estimate based on sample
        estimated_node_time = (total_nodes / 1000) * sample_time
        estimated_rel_time = estimated_node_time * 1.5  # Relationships usually take longer
      
        total_estimated = estimated_node_time + estimated_rel_time
      
        self.logger.info(f"Estimated export time: {total_estimated/60:.1f} minutes")
        return total_estimated
  
    def full_export_optimized(self):
        """Perform optimized full export"""
        self.logger.info(f"🚀 Starting optimized export to: {self.export_dir}")
      
        start_time = time.time()
      
        try:
            # Get database overview
            total_nodes, total_rels = self.get_total_counts()
          
            # Export database statistics and schema early
            self.export_database_stats()
            self.export_schema()
          
            # Estimate time
            estimated_time = self.estimate_export_time()
          
            # Choose export strategy based on size (nodes are primary driver)
            if total_nodes > 1000000:  # 1M+ nodes
                self.logger.info("Large dataset detected - using parallel label-based node export")
                node_count = self.export_by_label_parallel()
            else:
                self.logger.info("Using streaming node export")
                node_count = self.export_nodes_streaming()
          
            # Export relationships (always streaming, as they dont have labels)
            rel_count = self.export_relationships_streaming()
          
            # Create summary
            end_time = time.time()
            duration = end_time - start_time
          
            summary = {
                'export_completed': datetime.now().isoformat(),
                'duration_seconds': duration,
                'duration_minutes': duration / 60,
                'nodes_exported': node_count,
                'relationships_exported': rel_count,
                'export_rate_nodes_per_second': node_count / duration if duration > 0 else 0,
                'export_rate_relationships_per_second': rel_count / duration if duration > 0 else 0,
                'batch_size': self.batch_size,
                'max_workers': self.max_workers,
                'compressed': self.compress_output
            }
          
            with open(f"{self.export_dir}/export_summary.json", 'w') as f:
                json.dump(summary, f, indent=2, cls=Neo4jJSONEncoder)
          
            self.logger.info(f"✅ Export completed in {duration/60:.1f} minutes")
            self.logger.info(f"📁 Files saved to: {self.export_dir}")
            self.logger.info(f"📊 Exported {node_count:,} nodes and {rel_count:,} relationships")
          
        except Exception as e:
            self.logger.error(f"❌ Export failed: {str(e)}")
            raise

    def _write_json_line(self, file_handle, obj):
        """Write a JSON line using custom encoder"""
        file_handle.write(json.dumps(obj, cls=Neo4jJSONEncoder) + '\n')

def main():
    """Main function with command-line argument parsing"""
    parser = argparse.ArgumentParser(description='Export Neo4j database to structured files')
    parser.add_argument('--uri', required=True, help='Neo4j connection URI (e.g., bolt://localhost:7687)')
    parser.add_argument('--username', required=True, help='Neo4j username')
    parser.add_argument('--password', required=True, help='Neo4j password')
    parser.add_argument('--database', default='neo4j', help='Database name (default: neo4j)')
    parser.add_argument('--batch-size', type=int, default=10000, help='Batch size for export (default: 10000)')
    parser.add_argument('--max-workers', type=int, default=4, help='Max worker threads (default: 4)')
    parser.add_argument('--no-compress', action='store_true', help='Disable output compression')
    
    args = parser.parse_args()
    
    # Extract container name from URI for export directory naming
    container_name = args.uri.split(':')[-1] if ':' in args.uri else 'neo4j'
    export_base_name = f"neo4j_export/neo4j_export_{container_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    exporter = None
    try:
        exporter = HighPerformanceNeo4jExporter(
            uri=args.uri,
            username=args.username,
            password=args.password,
            database=args.database,
            batch_size=args.batch_size,
            max_workers=args.max_workers,
            compress_output=not args.no_compress
        )
        
        # Override export directory name
        exporter.export_dir = export_base_name
        os.makedirs(exporter.export_dir, exist_ok=True)
        
        exporter.full_export_optimized()
        
    except Exception as e:
        print(f"❌ Export failed: {str(e)}")
        sys.exit(1)
        
    finally:
        if exporter:
            exporter.close()

if __name__ == "__main__":
    main() 