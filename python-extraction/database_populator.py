#!/usr/bin/env python3
# database_populator.py - Populate SQLite database with extracted medical data

import json
import sqlite3
import logging
from pathlib import Path
import shutil
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DatabasePopulator:
    def __init__(self, db_path="../output/databases/medical_conditions.sqlite"):
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Backup existing database if it exists
        if self.db_path.exists():
            backup_path = self.db_path.parent / f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.sqlite"
            shutil.copy2(self.db_path, backup_path)
            logger.info(f"Backed up existing database to {backup_path}")
        
        self._setup_database()
    
    def _setup_database(self):
        logger.info(f"Setting up database at {self.db_path}")
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Enable foreign keys
        cursor.execute("PRAGMA foreign_keys = ON")
        
        # Create diseases table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS diseases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name_english TEXT NOT NULL,
            name_portuguese TEXT NOT NULL,
            category TEXT NOT NULL,
            severity TEXT NOT NULL,
            description_english TEXT,
            description_portuguese TEXT,
            source_pdf TEXT,
            extraction_confidence REAL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        
        # Create symptoms table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS symptoms (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_id INTEGER NOT NULL,
            symptom_english TEXT NOT NULL,
            symptom_portuguese TEXT NOT NULL,
            is_chief_complaint BOOLEAN DEFAULT FALSE,
            FOREIGN KEY (disease_id) REFERENCES diseases(id) ON DELETE CASCADE
        )
        """)
        
        # Create physical_findings table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS physical_findings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_id INTEGER NOT NULL,
            finding_english TEXT NOT NULL,
            finding_portuguese TEXT NOT NULL,
            FOREIGN KEY (disease_id) REFERENCES diseases(id) ON DELETE CASCADE
        )
        """)
        
        # Create lab_results table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS lab_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_id INTEGER NOT NULL,
            result_english TEXT NOT NULL,
            result_portuguese TEXT NOT NULL,
            FOREIGN KEY (disease_id) REFERENCES diseases(id) ON DELETE CASCADE
        )
        """)
        
        # Create diagnostic_hints table
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS diagnostic_hints (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            disease_id INTEGER NOT NULL,
            hint_english TEXT NOT NULL,
            hint_portuguese TEXT NOT NULL,
            FOREIGN KEY (disease_id) REFERENCES diseases(id) ON DELETE CASCADE
        )
        """)
        
        # Create indexes for better performance
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_diseases_category ON diseases(category)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_symptoms_disease_id ON symptoms(disease_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_symptoms_chief ON symptoms(is_chief_complaint)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_findings_disease_id ON physical_findings(disease_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_lab_disease_id ON lab_results(disease_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_hints_disease_id ON diagnostic_hints(disease_id)")
        
        conn.commit()
        conn.close()
        logger.info("Database tables created successfully")
    
    def clear_database(self):
        logger.info("Clearing existing data from database")
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Delete in correct order due to foreign keys
        cursor.execute("DELETE FROM diagnostic_hints")
        cursor.execute("DELETE FROM lab_results")
        cursor.execute("DELETE FROM physical_findings")
        cursor.execute("DELETE FROM symptoms")
        cursor.execute("DELETE FROM diseases")
        
        # Reset auto-increment counters
        cursor.execute("DELETE FROM sqlite_sequence WHERE name IN ('diseases', 'symptoms', 'physical_findings', 'lab_results', 'diagnostic_hints')")
        
        conn.commit()
        conn.close()
        logger.info("Database cleared")
    
    def load_conditions_from_json(self, json_file_path):
        logger.info(f"Loading conditions from {json_file_path}")
        
        with open(json_file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Handle different JSON formats
        if isinstance(data, dict) and 'conditions' in data:
            conditions = data['conditions']
        elif isinstance(data, list):
            conditions = data
        else:
            raise ValueError("Unknown JSON format")
        
        logger.info(f"Loaded {len(conditions)} conditions from JSON")
        return conditions
    
    def populate_from_json(self, json_file_path, clear_existing=True):
        if clear_existing:
            self.clear_database()
        
        conditions = self.load_conditions_from_json(json_file_path)
        self.populate_from_conditions(conditions)
    
    def populate_from_conditions(self, conditions):
        logger.info(f"Populating database with {len(conditions)} conditions")
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        successful_insertions = 0
        failed_insertions = []
        
        for i, condition in enumerate(conditions):
            try:
                # Insert disease
                cursor.execute("""
                INSERT INTO diseases 
                (name_english, name_portuguese, category, severity, description_english, description_portuguese, source_pdf, extraction_confidence)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    condition.get('name_english', 'Unknown'),
                    condition.get('name_portuguese', 'Desconhecido'),
                    condition.get('category', 'Other'),
                    condition.get('severity', 'Variable'),
                    condition.get('description_english', ''),
                    condition.get('description_portuguese', ''),
                    condition.get('source_pdf', ''),
                    condition.get('extraction_confidence', 0.0)
                ))
                
                disease_id = cursor.lastrowid
                
                # Insert symptoms
                symptoms = condition.get('symptoms', [])
                for symptom in symptoms:
                    cursor.execute("""
                    INSERT INTO symptoms (disease_id, symptom_english, symptom_portuguese, is_chief_complaint)
                    VALUES (?, ?, ?, ?)
                    """, (
                        disease_id,
                        symptom.get('english', ''),
                        symptom.get('portuguese', ''),
                        symptom.get('is_chief', False)
                    ))
                
                # Insert physical findings
                findings = condition.get('physical_findings', [])
                for finding in findings:
                    cursor.execute("""
                    INSERT INTO physical_findings (disease_id, finding_english, finding_portuguese)
                    VALUES (?, ?, ?)
                    """, (
                        disease_id,
                        finding.get('english', ''),
                        finding.get('portuguese', '')
                    ))
                
                # Insert lab results
                lab_results = condition.get('lab_results', [])
                for result in lab_results:
                    cursor.execute("""
                    INSERT INTO lab_results (disease_id, result_english, result_portuguese)
                    VALUES (?, ?, ?)
                    """, (
                        disease_id,
                        result.get('english', ''),
                        result.get('portuguese', '')
                    ))
                
                # Insert diagnostic hints
                hints = condition.get('diagnostic_hints', [])
                for hint in hints:
                    cursor.execute("""
                    INSERT INTO diagnostic_hints (disease_id, hint_english, hint_portuguese)
                    VALUES (?, ?, ?)
                    """, (
                        disease_id,
                        hint.get('english', ''),
                        hint.get('portuguese', '')
                    ))
                
                successful_insertions += 1
                if (i + 1) % 10 == 0:
                    logger.info(f"Processed {i + 1}/{len(conditions)} conditions")
                
            except Exception as e:
                error_info = {
                    'condition_name': condition.get('name_english', 'Unknown'),
                    'error': str(e)
                }
                failed_insertions.append(error_info)
                logger.warning(f"Failed to insert condition {i + 1}: {e}")
                continue
        
        conn.commit()
        conn.close()
        
        logger.info(f"Successfully inserted {successful_insertions} conditions")
        if failed_insertions:
            logger.warning(f"Failed to insert {len(failed_insertions)} conditions")
    
    def get_database_stats(self):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        stats = {}
        
        # Count diseases by category
        cursor.execute("SELECT category, COUNT(*) FROM diseases GROUP BY category ORDER BY COUNT(*) DESC")
        stats['diseases_by_category'] = dict(cursor.fetchall())
        
        # Total counts
        cursor.execute("SELECT COUNT(*) FROM diseases")
        stats['total_diseases'] = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM symptoms")
        stats['total_symptoms'] = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM symptoms WHERE is_chief_complaint = 1")
        stats['total_chief_complaints'] = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM physical_findings")
        stats['total_physical_findings'] = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM lab_results")
        stats['total_lab_results'] = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM diagnostic_hints")
        stats['total_diagnostic_hints'] = cursor.fetchone()[0]
        
        # Average confidence
        cursor.execute("SELECT AVG(extraction_confidence) FROM diseases WHERE extraction_confidence > 0")
        avg_confidence = cursor.fetchone()[0]
        stats['average_confidence'] = round(avg_confidence, 3) if avg_confidence else 0
        
        conn.close()
        return stats
    
    def export_for_swift_app(self, output_path="../output/databases/"):
        output_dir = Path(output_path)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Copy database to output location
        swift_db_path = output_dir / "medical_database.sqlite"
        shutil.copy2(self.db_path, swift_db_path)
        
        logger.info(f"Database exported for Swift app: {swift_db_path}")
        logger.info("To use in your Swift app:")
        logger.info("1. Copy this database file to your app's Documents directory")
        logger.info("2. Update your DatabaseManager to use the populated data")
        logger.info("3. Remove the sample data insertion code")
        
        return swift_db_path

def main():
    logger.info("=== Database Population Started ===")
    
    # Configuration
    EXTRACTED_DATA_DIR = "../output/extracted_data"
    DATABASE_PATH = "../output/databases/medical_conditions.sqlite"
    
    try:
        # Initialize populator
        populator = DatabasePopulator(DATABASE_PATH)
        
        # Find JSON files with extracted data
        data_dir = Path(EXTRACTED_DATA_DIR)
        if not data_dir.exists():
            logger.error(f"Extracted data directory not found: {EXTRACTED_DATA_DIR}")
            logger.info("Please run the PDF extraction script first")
            return
        
        # Look for the combined file first
        combined_file = data_dir / "all_conditions_combined.json"
        if combined_file.exists():
            logger.info(f"Found combined data file: {combined_file}")
            populator.populate_from_json(str(combined_file))
        else:
            # Process individual files
            json_files = list(data_dir.glob("*_final.json"))
            if not json_files:
                logger.error("No extracted data files found")
                logger.info("Please run the PDF extraction script first")
                return
            
            logger.info(f"Found {len(json_files)} data files to process")
            
            # Combine all conditions
            all_conditions = []
            for json_file in json_files:
                conditions = populator.load_conditions_from_json(str(json_file))
                all_conditions.extend(conditions)
            
            # Populate database
            populator.clear_database()
            populator.populate_from_conditions(all_conditions)
        
        # Print statistics
        stats = populator.get_database_stats()
        logger.info(f"\n=== DATABASE POPULATION COMPLETE ===")
        logger.info(f"Total diseases: {stats['total_diseases']}")
        logger.info(f"Total symptoms: {stats['total_symptoms']} ({stats['total_chief_complaints']} chief complaints)")
        logger.info(f"Total physical findings: {stats['total_physical_findings']}")
        logger.info(f"Total lab results: {stats['total_lab_results']}")
        logger.info(f"Total diagnostic hints: {stats['total_diagnostic_hints']}")
        logger.info(f"Average extraction confidence: {stats['average_confidence']}")
        
        logger.info(f"\nDiseases by category:")
        for category, count in stats['diseases_by_category'].items():
            logger.info(f"  {category}: {count}")
        
        # Export for Swift app
        swift_db_path = populator.export_for_swift_app()
        logger.info(f"\nDatabase ready for Swift app: {swift_db_path}")
        
    except Exception as e:
        logger.error(f"Critical error: {e}")
        raise

if __name__ == "__main__":
    main()
