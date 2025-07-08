
#!/usr/bin/env python3
# manual_curator.py - Manual review tools for extracted medical data

import json
import pandas as pd
from pathlib import Path
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ManualReviewTool:
    def __init__(self, input_dir="../output/extracted_data", output_dir="../output/reviewed_data"):
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        logger.info("Manual Review Tool initialized")
    
    def load_extracted_data(self, filename=None):
        if filename:
            file_path = self.input_dir / filename
        else:
            # Look for combined file first
            combined_file = self.input_dir / "all_conditions_combined.json"
            if combined_file.exists():
                file_path = combined_file
            else:
                # Get the first JSON file found
                json_files = list(self.input_dir.glob("*.json"))
                if not json_files:
                    logger.error("No JSON files found in input directory")
                    return []
                file_path = json_files[0]
        
        logger.info(f"Loading data from: {file_path}")
        
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Handle different JSON formats
        if isinstance(data, dict) and 'conditions' in data:
            conditions = data['conditions']
        elif isinstance(data, list):
            conditions = data
        else:
            logger.error("Unknown JSON format")
            return []
        
        logger.info(f"Loaded {len(conditions)} conditions")
        return conditions
    
    def export_to_excel(self, conditions, output_filename="medical_conditions_for_review.xlsx"):
        logger.info(f"Exporting {len(conditions)} conditions to Excel")
        
        excel_data = []
        for condition in conditions:
            row = {
                'name_english': condition.get('name_english', ''),
                'name_portuguese': condition.get('name_portuguese', ''),
                'category': condition.get('category', ''),
                'severity': condition.get('severity', ''),
                'description_english': condition.get('description_english', ''),
                'description_portuguese': condition.get('description_portuguese', ''),
                'confidence': condition.get('extraction_confidence', 0),
            }
            
            # Flatten symptoms
            symptoms = condition.get('symptoms', [])
            chief_complaints = [s.get('english', '') for s in symptoms if s.get('is_chief')]
            other_symptoms = [s.get('english', '') for s in symptoms if not s.get('is_chief')]
            
            row['chief_complaints'] = '; '.join(chief_complaints)
            row['other_symptoms'] = '; '.join(other_symptoms)
            row['physical_findings'] = '; '.join([f.get('english', '') for f in condition.get('physical_findings', [])])
            row['lab_results'] = '; '.join([r.get('english', '') for r in condition.get('lab_results', [])])
            row['diagnostic_hints'] = '; '.join([h.get('english', '') for h in condition.get('diagnostic_hints', [])])
            
            excel_data.append(row)
        
        df = pd.DataFrame(excel_data)
        output_path = self.output_dir / output_filename
        df.to_excel(output_path, index=False)
        
        logger.info(f"Excel file created: {output_path}")
        logger.info("You can now manually review and edit this file")
        logger.info("After editing, use import_from_excel() to load the changes")
        
        return output_path
    
    def import_from_excel(self, excel_filename="medical_conditions_for_review.xlsx"):
        excel_path = self.output_dir / excel_filename
        
        if not excel_path.exists():
            logger.error(f"Excel file not found: {excel_path}")
            return []
        
        logger.info(f"Importing reviewed data from: {excel_path}")
        
        df = pd.read_excel(excel_path)
        
        # Convert back to our format
        conditions = []
        for _, row in df.iterrows():
            condition = {
                'name_english': row.get('name_english', ''),
                'name_portuguese': row.get('name_portuguese', ''),
                'category': row.get('category', ''),
                'severity': row.get('severity', ''),
                'description_english': row.get('description_english', ''),
                'description_portuguese': row.get('description_portuguese', ''),
                'extraction_confidence': row.get('confidence', 0),
                'symptoms': [],
                'physical_findings': [],
                'lab_results': [],
                'diagnostic_hints': []
            }
            
            # Parse symptoms
            if pd.notna(row.get('chief_complaints')):
                for symptom in str(row['chief_complaints']).split(';'):
                    if symptom.strip():
                        condition['symptoms'].append({
                            'english': symptom.strip(),
                            'portuguese': symptom.strip(),  # Will need manual translation
                            'is_chief': True
                        })
            
            if pd.notna(row.get('other_symptoms')):
                for symptom in str(row['other_symptoms']).split(';'):
                    if symptom.strip():
                        condition['symptoms'].append({
                            'english': symptom.strip(),
                            'portuguese': symptom.strip(),
                            'is_chief': False
                        })
            
            # Parse other fields
            for field, list_key in [
                ('physical_findings', 'physical_findings'),
                ('lab_results', 'lab_results'),
                ('diagnostic_hints', 'diagnostic_hints')
            ]:
                if pd.notna(row.get(field)):
                    for item in str(row[field]).split(';'):
                        if item.strip():
                            condition[list_key].append({
                                'english': item.strip(),
                                'portuguese': item.strip()
                            })
            
            conditions.append(condition)
        
        logger.info(f"Imported {len(conditions)} conditions from Excel")
        return conditions
    
    def save_reviewed_data(self, conditions, output_filename="reviewed_conditions.json"):
        output_path = self.output_dir / output_filename
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(conditions, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Reviewed data saved to: {output_path}")
        return output_path
    
    def create_template(self, output_filename="medical_conditions_template.xlsx"):
        template_data = {
            'name_english': ['Enter disease name in English', 'Acute Myocardial Infarction'],
            'name_portuguese': ['Enter disease name in Portuguese', 'Infarto Agudo do Miocárdio'],
            'category': ['Cardiovascular/Respiratory/etc.', 'Cardiovascular'],
            'severity': ['Mild/Moderate/Severe/Critical/Chronic', 'Critical'],
            'description_english': ['Brief clinical description', 'Acute coronary syndrome...'],
            'description_portuguese': ['Descrição clínica breve', 'Síndrome coronariana aguda...'],
            'chief_complaints': ['Main symptoms (separate with ;)', 'Crushing chest pain; Shortness of breath'],
            'other_symptoms': ['Additional symptoms (separate with ;)', 'Diaphoresis; Left arm pain'],
            'physical_findings': ['Physical exam findings (separate with ;)', 'S4 gallop; Diaphoresis'],
            'lab_results': ['Lab/imaging results (separate with ;)', 'Elevated troponin; ECG shows ST elevation'],
            'diagnostic_hints': ['Clinical pearls (separate with ;)', 'Check cardiac enzymes; Ask about risk factors']
        }
        
        df = pd.DataFrame(template_data)
        output_path = self.output_dir / output_filename
        df.to_excel(output_path, index=False)
        
        logger.info(f"Template created: {output_path}")
        return output_path

def main():
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--create-template":
        # Create a template for manual data entry
        tool = ManualReviewTool()
        tool.create_template()
        return
    
    # Load extracted data and export to Excel for review
    tool = ManualReviewTool()
    
    # Load the extracted conditions
    conditions = tool.load_extracted_data()
    
    if not conditions:
        logger.error("No conditions found to review")
        logger.info("Please run the PDF extraction script first")
        return
    
    # Export to Excel for manual review
    excel_file = tool.export_to_excel(conditions)
    
    logger.info("\n=== NEXT STEPS ===")
    logger.info(f"1. Open the Excel file: {excel_file}")
    logger.info("2. Review and edit the medical conditions")
    logger.info("3. Save the Excel file")
    logger.info("4. Run this script again to import the reviewed data:")
    logger.info("   python3 manual_curator.py --import")

if __name__ == "__main__":
    main()
