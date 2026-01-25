#!/usr/bin/env python3
# pdf_extractor.py - Full AI-Powered Medical PDF Extraction Tool
import json
import re
import os
import sys
import time
from pathlib import Path
import logging
from dotenv import load_dotenv

# Load environment variables
load_dotenv('../config/.env')

# Required packages
try:
    import PyPDF2
    import pdfplumber
    import pandas as pd
    from anthropic import Anthropic
except ImportError as e:
    print(f"Missing required package: {e}")
    print("Please run: pip install PyPDF2 pdfplumber anthropic pandas openpyxl python-dotenv")
    sys.exit(1)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class MedicalCondition:
    def __init__(self, name_english="", name_portuguese="", category="", severity="",
                 description_english="", description_portuguese="", symptoms=None,
                 physical_findings=None, lab_results=None, diagnostic_hints=None,
                 treatments=None, source_pdf="", extraction_confidence=0.0):
        self.name_english = name_english
        self.name_portuguese = name_portuguese
        self.category = category
        self.severity = severity
        self.description_english = description_english
        self.description_portuguese = description_portuguese
        self.symptoms = symptoms or []
        self.physical_findings = physical_findings or []
        self.lab_results = lab_results or []
        self.diagnostic_hints = diagnostic_hints or []
        self.treatments = treatments or []
        self.source_pdf = source_pdf
        self.extraction_confidence = extraction_confidence

    def to_dict(self):
        return {
            'name_english': self.name_english,
            'name_portuguese': self.name_portuguese,
            'category': self.category,
            'severity': self.severity,
            'description_english': self.description_english,
            'description_portuguese': self.description_portuguese,
            'symptoms': self.symptoms,
            'physical_findings': self.physical_findings,
            'lab_results': self.lab_results,
            'diagnostic_hints': self.diagnostic_hints,
            'treatments': self.treatments,
            'source_pdf': self.source_pdf,
            'extraction_confidence': self.extraction_confidence
        }

class MedicalPDFExtractor:
    def __init__(self, anthropic_api_key, output_dir="../output"):
        self.anthropic = Anthropic(api_key=anthropic_api_key)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Create subdirectories
        (self.output_dir / "extracted_data").mkdir(exist_ok=True)
        (self.output_dir / "logs").mkdir(exist_ok=True)
        (self.output_dir / "temp").mkdir(exist_ok=True)
        
        # Rate limiting for API calls
        self.last_api_call = 0
        self.api_delay = float(os.getenv('API_DELAY_SECONDS', '1.0'))
        
        logger.info("Full AI-Powered PDF Extractor initialized")
    
    def extract_text_from_pdf(self, pdf_path, max_pages=None):
        logger.info(f"Extracting text from: {pdf_path}")
        
        text = ""
        metadata = {
            "total_pages": 0,
            "processed_pages": 0,
            "extraction_method": "pdfplumber",
            "errors": []
        }
        
        try:
            with pdfplumber.open(pdf_path) as pdf:
                metadata["total_pages"] = len(pdf.pages)
                pages_to_process = min(len(pdf.pages), max_pages or len(pdf.pages))
                
                logger.info(f"Processing {pages_to_process} pages out of {len(pdf.pages)} total pages")
                
                for i, page in enumerate(pdf.pages[:pages_to_process]):
                    try:
                        page_text = page.extract_text()
                        if page_text and len(page_text.strip()) > 50:
                            text += f"\n--- PAGE {i+1} ---\n{page_text}\n"
                            metadata["processed_pages"] += 1
                        
                        if (i + 1) % 50 == 0:
                            logger.info(f"Processed {i + 1}/{pages_to_process} pages...")
                            
                    except Exception as e:
                        metadata["errors"].append(f"Page {i+1}: {str(e)}")
                        logger.warning(f"Error on page {i+1}: {e}")
                        
        except Exception as e:
            logger.warning(f"pdfplumber failed, trying PyPDF2: {e}")
            metadata["extraction_method"] = "PyPDF2"
            
            try:
                with open(pdf_path, 'rb') as file:
                    pdf_reader = PyPDF2.PdfReader(file)
                    metadata["total_pages"] = len(pdf_reader.pages)
                    pages_to_process = min(len(pdf_reader.pages), max_pages or len(pdf_reader.pages))
                    
                    logger.info(f"PyPDF2: Processing {pages_to_process} pages")
                    
                    for i, page in enumerate(pdf_reader.pages[:pages_to_process]):
                        try:
                            page_text = page.extract_text()
                            if page_text and len(page_text.strip()) > 50:
                                text += f"\n--- PAGE {i+1} ---\n{page_text}\n"
                                metadata["processed_pages"] += 1
                        except Exception as e:
                            metadata["errors"].append(f"Page {i+1}: {str(e)}")
                            
                        if (i + 1) % 50 == 0:
                            logger.info(f"PyPDF2: Processed {i + 1}/{pages_to_process} pages...")
                            
            except Exception as e:
                logger.error(f"Both extraction methods failed: {e}")
                metadata["errors"].append(f"Complete failure: {str(e)}")
        
        logger.info(f"Extracted {len(text):,} characters from {metadata['processed_pages']} pages")
        return text, metadata
    
    def chunk_text_intelligently(self, text, max_chunk_size=3000):
        logger.info("Creating intelligent text chunks...")
        
        paragraphs = [p.strip() for p in text.split('\n\n') if len(p.strip()) > 100]
        chunks = []
        current_chunk = ""
        
        for paragraph in paragraphs:
            if len(current_chunk + paragraph) > max_chunk_size and current_chunk:
                relevance = self._estimate_medical_relevance(current_chunk)
                if relevance > 0.3:
                    chunks.append({
                        "text": current_chunk,
                        "type": "medical_content",
                        "estimated_relevance": relevance
                    })
                current_chunk = paragraph
            else:
                current_chunk += "\n\n" + paragraph
        
        if current_chunk:
            relevance = self._estimate_medical_relevance(current_chunk)
            if relevance > 0.3:
                chunks.append({
                    "text": current_chunk,
                    "type": "medical_content",
                    "estimated_relevance": relevance
                })
        
        chunks.sort(key=lambda x: x["estimated_relevance"], reverse=True)
        
        logger.info(f"Created {len(chunks)} intelligent chunks with relevance > 0.3")
        return chunks
    
    def _estimate_medical_relevance(self, text):
        medical_keywords = [
            'symptoms', 'diagnosis', 'treatment', 'patient', 'disease', 'condition',
            'syndrome', 'pathology', 'clinical', 'laboratory', 'findings', 'signs',
            'etiology', 'pathophysiology', 'manifestations', 'presentation', 'therapy'
        ]
        
        text_lower = text.lower()
        score = 0
        
        keyword_count = sum(1 for word in medical_keywords if word in text_lower)
        score += min(keyword_count * 0.08, 0.4)
        
        if re.search(r'\bmg/dl\b|\bmmHg\b|\bbpm\b', text):
            score += 0.1
        if re.search(r'patient[s]?\s+(?:present|with|have)', text_lower):
            score += 0.15
        
        if len(text) < 300:
            score *= 0.7
        
        return min(1.0, score)
    
    def _rate_limit(self):
        current_time = time.time()
        time_since_last = current_time - self.last_api_call
        
        if time_since_last < self.api_delay:
            sleep_time = self.api_delay - time_since_last
            time.sleep(sleep_time)
        
        self.last_api_call = time.time()
    
    def extract_medical_data_with_ai(self, chunk, attempt=1):
        self._rate_limit()
        
        prompt = f"""
You are a medical expert extracting information from a medical textbook.
ANALYZE this text and extract medical condition information IN ENGLISH.
If this text describes a clear medical condition/disease, return a JSON object. If not, return exactly "null".

REQUIRED JSON FORMAT (ENGLISH ONLY - Portuguese will be added later):
{{
    "disease_name": "Exact medical condition name in English",
    "category": "ONE of: Cardiovascular, Respiratory, Gastrointestinal, Neurological, Endocrine, Infectious, Hematological, Musculoskeletal, Dermatological, Psychiatric, Oncological, Other",
    "severity": "ONE of: Mild, Moderate, Severe, Critical, Chronic, Variable",
    "description": "2-3 sentence clinical description in English",
    "chief_complaints": ["2-4 main symptoms patients report in English"],
    "additional_symptoms": ["2-4 other possible symptoms in English"],
    "physical_findings": ["2-4 physical exam findings in English"],
    "laboratory_results": ["2-4 lab/imaging findings in English"],
    "diagnostic_hints": ["2-4 clinical pearls or diagnostic clues in English"],
    "treatments": [
        {{
            "treatment": "Specific treatment in English",
            "category": "ONE of: medication, procedure, lifestyle, supportive",
            "is_primary": true
        }}
    ],
    "confidence": 0.85
}}

TREATMENT CATEGORIES:
- medication: Drugs, antibiotics, antivirals, pain relievers, etc.
- procedure: Surgery, intubation, dialysis, medical procedures
- lifestyle: Rest, hydration, diet modifications, exercise
- supportive: Oxygen therapy, monitoring, palliative care

IMPORTANT TREATMENT RULES:
- Extract 2-5 treatments per condition
- Mark first-line/definitive treatments as "is_primary": true
- Mark supportive/adjunct treatments as "is_primary": false
- Be specific (e.g., "Broad-spectrum antibiotics" not just "antibiotics")
- Return ONLY English text. Portuguese translations will be added in a separate step.

TEXT TO ANALYZE:
{chunk['text'][:2500]}

Extract medical condition data in English or return "null":
"""
        
        try:
            response = self.anthropic.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=1200,
                messages=[{"role": "user", "content": prompt}]
            )
            
            content = response.content[0].text.strip()
            
            if content.lower().strip() == "null":
                return None
            
            content = re.sub(r'^\`\`\`json\s*', '', content)
            content = re.sub(r'\s*\`\`\`$', '', content)
            
            data = json.loads(content)
            
            required_fields = ['disease_name', 'category', 'description']
            if not all(field in data for field in required_fields):
                return None
            
            logger.info(f"✅ Extracted: {data['disease_name']}")
            return data
            
        except Exception as e:
            logger.warning(f"AI extraction error: {e}")
            return None
    
    def translate_to_portuguese(self, medical_data):
        self._rate_limit()
        
        # Create a prompt that asks for ADDITIONS, not replacements
        prompt = f"""
You are a medical translator. Take this English medical data and ADD Portuguese translations.
Return the SAME JSON structure but ADD Portuguese fields alongside English ones.

KEEP ALL EXISTING ENGLISH FIELDS. ADD these Portuguese fields:
- disease_name_portuguese
- description_portuguese
- chief_complaints_portuguese (array)
- additional_symptoms_portuguese (array)
- physical_findings_portuguese (array)
- laboratory_results_portuguese (array)
- diagnostic_hints_portuguese (array)
- treatments_portuguese (array of objects with "treatment" field translated)

For treatments, keep the same structure but translate the "treatment" field:
{{
    "treatment": "Portuguese translation",
    "category": "same as English (medication/procedure/lifestyle/supportive)",
    "is_primary": same boolean value
}}

INPUT: {json.dumps(medical_data, indent=2)}

OUTPUT: Same structure with Portuguese fields ADDED (not replaced):
"""
        
        try:
            response = self.anthropic.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=1500,
                messages=[{"role": "user", "content": prompt}]
            )
            
            content = response.content[0].text.strip()
            content = re.sub(r'^\`\`\`json\s*', '', content)
            content = re.sub(r'\s*\`\`\`$', '', content)
            
            translated_data = json.loads(content)
            
            # MERGE instead of replace - keep original English data
            merged_data = medical_data.copy()  # Start with English data
            
            # Add Portuguese translations
            portuguese_fields = [
                'disease_name_portuguese',
                'description_portuguese',
                'chief_complaints_portuguese',
                'additional_symptoms_portuguese',
                'physical_findings_portuguese',
                'laboratory_results_portuguese',
                'diagnostic_hints_portuguese',
                'treatments_portuguese'
            ]

            for field in portuguese_fields:
                if field in translated_data:
                    merged_data[field] = translated_data[field]
            
            logger.info(f"✅ Added Portuguese translations for: {merged_data.get('disease_name', 'Unknown')}")
            return merged_data
            
        except Exception as e:
            logger.warning(f"Translation error: {e}")
            # Return original data if translation fails
            return medical_data
    
    def process_pdf_complete(self, pdf_path, max_pages=None):
        pdf_name = Path(pdf_path).stem
        logger.info(f"Starting FULL processing of: {pdf_name}")
        
        try:
            text, metadata = self.extract_text_from_pdf(pdf_path, max_pages)
            if not text.strip():
                logger.error("No text extracted!")
                return []
            
            chunks = self.chunk_text_intelligently(text)
            if not chunks:
                logger.error("No valid chunks created!")
                return []
            
            logger.info(f"Processing {len(chunks)} chunks with AI...")
            
            medical_conditions = []
            max_conditions = int(os.getenv('MAX_CONDITIONS_PER_PDF', '999999'))
            
            for i, chunk in enumerate(chunks):
                logger.info(f"Processing chunk {i+1}/{len(chunks)} (relevance: {chunk['estimated_relevance']:.2f})")
                
                extracted_data = self.extract_medical_data_with_ai(chunk)
                if not extracted_data:
                    continue
                
                translated_data = self.translate_to_portuguese(extracted_data)
                condition = self._convert_to_medical_condition(translated_data, pdf_name)
                medical_conditions.append(condition)
                
                logger.info(f"Added: {condition.name_english} (Total: {len(medical_conditions)})")
            
            self._save_results(medical_conditions, pdf_name, metadata)
            
            logger.info(f"Completed {pdf_name}: {len(medical_conditions)} conditions extracted")
            return medical_conditions
            
        except Exception as e:
            logger.error(f"Critical error processing {pdf_name}: {e}")
            return []
    
    def _convert_to_medical_condition(self, data, source_pdf):
        def safe_get_list(key, portuguese_key):
            english_items = data.get(key, [])
            portuguese_items = data.get(portuguese_key, english_items)
            
            result = []
            for i, item in enumerate(english_items):
                result.append({
                    'english': item,
                    'portuguese': portuguese_items[i] if i < len(portuguese_items) else item
                })
            return result
        
        symptoms = []
        chief_complaints = data.get('chief_complaints', [])
        chief_complaints_pt = data.get('chief_complaints_portuguese', chief_complaints)
        
        for i, symptom in enumerate(chief_complaints):
            symptoms.append({
                'english': symptom,
                'portuguese': chief_complaints_pt[i] if i < len(chief_complaints_pt) else symptom,
                'is_chief': True
            })
        
        additional_symptoms = data.get('additional_symptoms', [])
        additional_symptoms_pt = data.get('additional_symptoms_portuguese', additional_symptoms)
        
        for i, symptom in enumerate(additional_symptoms):
            symptoms.append({
                'english': symptom,
                'portuguese': additional_symptoms_pt[i] if i < len(additional_symptoms_pt) else symptom,
                'is_chief': False
            })

        # Process treatments
        treatments = []
        treatments_en = data.get('treatments', [])
        treatments_pt = data.get('treatments_portuguese', [])

        for i, treatment_en in enumerate(treatments_en):
            treatment_pt = treatments_pt[i] if i < len(treatments_pt) else treatment_en

            # Handle both dict and string formats
            if isinstance(treatment_en, dict):
                treatments.append({
                    'english': treatment_en.get('treatment', ''),
                    'portuguese': treatment_pt.get('treatment', treatment_en.get('treatment', '')) if isinstance(treatment_pt, dict) else treatment_en.get('treatment', ''),
                    'category': treatment_en.get('category', 'medication'),
                    'is_primary': treatment_en.get('is_primary', False)
                })
            else:
                # If it's just a string, assume it's medication and primary
                treatments.append({
                    'english': treatment_en,
                    'portuguese': treatment_pt if isinstance(treatment_pt, str) else treatment_en,
                    'category': 'medication',
                    'is_primary': True
                })

        return MedicalCondition(
            name_english=data.get('disease_name', 'Unknown Condition'),
            name_portuguese=data.get('disease_name_portuguese', data.get('disease_name', 'Condição Desconhecida')),
            category=data.get('category', 'Other'),
            severity=data.get('severity', 'Variable'),
            description_english=data.get('description', ''),
            description_portuguese=data.get('description_portuguese', data.get('description', '')),
            symptoms=symptoms,
            physical_findings=safe_get_list('physical_findings', 'physical_findings_portuguese'),
            lab_results=safe_get_list('laboratory_results', 'laboratory_results_portuguese'),
            diagnostic_hints=safe_get_list('diagnostic_hints', 'diagnostic_hints_portuguese'),
            treatments=treatments,
            source_pdf=source_pdf,
            extraction_confidence=data.get('confidence', 0.0)
        )
    
    def _save_results(self, conditions, pdf_name, metadata):
        try:
            results = {
                'metadata': {
                    'source_pdf': pdf_name,
                    'extraction_date': time.strftime('%Y-%m-%d %H:%M:%S'),
                    'total_conditions': len(conditions),
                    'pdf_metadata': metadata
                },
                'conditions': [condition.to_dict() for condition in conditions]
            }
            
            output_file = self.output_dir / "extracted_data" / f"{pdf_name}_final.json"
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(results, f, indent=2, ensure_ascii=False)
            
            logger.info(f"Results saved to: {output_file}")
            
        except Exception as e:
            logger.error(f"Failed to save results: {e}")

def main():
    ANTHROPIC_API_KEY = os.getenv('ANTHROPIC_API_KEY') or "API_KEY_PLACEHOLDER"
    PDF_DIRECTORY = "../pdfs"
    OUTPUT_DIRECTORY = "../output"
    MAX_PAGES_FOR_TESTING = os.getenv('MAX_PAGES_FOR_TESTING')
    
    if MAX_PAGES_FOR_TESTING:
        try:
            MAX_PAGES_FOR_TESTING = int(MAX_PAGES_FOR_TESTING)
        except ValueError:
            MAX_PAGES_FOR_TESTING = None
    else:
        MAX_PAGES_FOR_TESTING = None
    
    logger.info("=== AI-POWERED Medical PDF Extraction Started ===")
    
    if MAX_PAGES_FOR_TESTING:
        logger.info(f"TESTING MODE: Limited to {MAX_PAGES_FOR_TESTING} pages per PDF")
    else:
        logger.info("FULL MODE: Processing all pages")
    
    try:
        extractor = MedicalPDFExtractor(ANTHROPIC_API_KEY, OUTPUT_DIRECTORY)
        
        pdf_dir = Path(PDF_DIRECTORY)
        if not pdf_dir.exists():
            logger.error(f"PDF directory not found: {PDF_DIRECTORY}")
            return
        
        pdf_files = list(pdf_dir.glob("*.pdf"))
        if not pdf_files:
            logger.error(f"No PDF files found in {PDF_DIRECTORY}")
            return
        
        logger.info(f"Found {len(pdf_files)} PDF files to process")
        
        all_conditions = []
        successful_pdfs = 0
        
        for i, pdf_file in enumerate(pdf_files):
            logger.info(f"Processing PDF {i+1}/{len(pdf_files)}: {pdf_file.name}")
            
            try:
                conditions = extractor.process_pdf_complete(str(pdf_file), MAX_PAGES_FOR_TESTING)
                if conditions:
                    all_conditions.extend(conditions)
                    successful_pdfs += 1
                    logger.info(f"Successfully processed {pdf_file.name}: {len(conditions)} conditions")
                else:
                    logger.warning(f"No conditions extracted from {pdf_file.name}")
                    
            except Exception as e:
                logger.error(f"Failed to process {pdf_file.name}: {e}")
                continue
        
        if all_conditions:
            combined_file = Path(OUTPUT_DIRECTORY) / "extracted_data" / "all_conditions_combined.json"
            with open(combined_file, 'w', encoding='utf-8') as f:
                json.dump([condition.to_dict() for condition in all_conditions], f, indent=2, ensure_ascii=False)
        
        logger.info(f"=== EXTRACTION COMPLETE ===")
        logger.info(f"Successfully processed: {successful_pdfs}/{len(pdf_files)} PDFs")
        logger.info(f"Total conditions extracted: {len(all_conditions)}")
        
    except Exception as e:
        logger.error(f"Critical error: {e}")
        raise

if __name__ == "__main__":
    main()
