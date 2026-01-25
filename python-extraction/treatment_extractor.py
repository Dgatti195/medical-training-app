#!/usr/bin/env python3
# treatment_extractor.py - Extract treatments for existing diseases in database

import json
import sqlite3
import logging
import time
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv('../config/.env')

# Required packages
try:
    from anthropic import Anthropic
    import pdfplumber
except ImportError as e:
    print(f"Missing required package: {e}")
    print("Please run: pip install anthropic pdfplumber python-dotenv")
    sys.exit(1)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class TreatmentExtractor:
    def __init__(self, db_path, pdf_path, anthropic_api_key):
        self.db_path = Path(db_path)
        self.pdf_path = Path(pdf_path)
        self.anthropic = Anthropic(api_key=anthropic_api_key)

        # Rate limiting
        self.last_api_call = 0
        self.api_delay = float(os.getenv('API_DELAY_SECONDS', '1.5'))

        logger.info(f"Treatment Extractor initialized")
        logger.info(f"Database: {self.db_path}")
        logger.info(f"PDF: {self.pdf_path}")

    def _rate_limit(self):
        """Enforce rate limiting for API calls"""
        current_time = time.time()
        time_since_last = current_time - self.last_api_call

        if time_since_last < self.api_delay:
            sleep_time = self.api_delay - time_since_last
            time.sleep(sleep_time)

        self.last_api_call = time.time()

    def get_diseases_without_treatments(self):
        """Get all diseases that don't have treatments yet"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        # Get diseases that don't have any treatments
        cursor.execute("""
            SELECT d.id, d.name_english, d.name_portuguese, d.category
            FROM diseases d
            LEFT JOIN treatments t ON d.id = t.disease_id
            WHERE t.id IS NULL
            ORDER BY d.id
        """)

        diseases = []
        for row in cursor.fetchall():
            diseases.append({
                'id': row[0],
                'name_english': row[1],
                'name_portuguese': row[2],
                'category': row[3]
            })

        conn.close()
        logger.info(f"Found {len(diseases)} diseases without treatments")
        return diseases

    def search_pdf_for_disease(self, disease_name):
        """Search PDF for disease-specific text"""
        logger.info(f"Searching PDF for: {disease_name}")

        try:
            with pdfplumber.open(self.pdf_path) as pdf:
                disease_text = ""
                found_disease = False

                for page_num, page in enumerate(pdf.pages):
                    page_text = page.extract_text()

                    if not page_text:
                        continue

                    # Check if this page mentions the disease
                    if disease_name.lower() in page_text.lower():
                        found_disease = True
                        disease_text += f"\n{page_text}\n"

                        # Get next page too for context
                        if page_num + 1 < len(pdf.pages):
                            next_page_text = pdf.pages[page_num + 1].extract_text()
                            if next_page_text:
                                disease_text += f"\n{next_page_text}\n"

                        # We found the disease, no need to continue
                        break

                if not found_disease:
                    logger.warning(f"Disease '{disease_name}' not found in PDF")
                    return None

                logger.info(f"Found {len(disease_text)} characters of text for {disease_name}")
                return disease_text[:5000]  # Limit to 5000 chars

        except Exception as e:
            logger.error(f"Error reading PDF: {e}")
            return None

    def extract_treatments_with_ai(self, disease_name, disease_text):
        """Use AI to extract treatments from disease text"""
        self._rate_limit()

        prompt = f"""
You are a medical expert. Provide standard treatment information for {disease_name}.

Based on your medical knowledge and the text below, return a JSON array of 2-5 treatments.

Each treatment must have:
- "treatment": Specific treatment description in English
- "category": ONE of: medication, procedure, lifestyle, supportive
- "is_primary": true for first-line/definitive treatments, false for supportive/adjunct

TREATMENT CATEGORIES:
- medication: Drugs, antibiotics, antivirals, pain relievers
- procedure: Surgery, intubation, dialysis, medical procedures
- lifestyle: Rest, hydration, diet modifications
- supportive: Oxygen therapy, monitoring, palliative care

EXAMPLE OUTPUT:
[
  {{"treatment": "Broad-spectrum antibiotics (e.g., ceftriaxone)", "category": "medication", "is_primary": true}},
  {{"treatment": "Intravenous fluids for hydration", "category": "supportive", "is_primary": false}}
]

REFERENCE TEXT (if treatments are mentioned, use them; otherwise use your medical knowledge):
{disease_text[:3000]}

Return ONLY a valid JSON array (no other text):
"""

        try:
            response = self.anthropic.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=800,
                messages=[{"role": "user", "content": prompt}]
            )

            content = response.content[0].text.strip()

            # Log the raw response for debugging
            logger.debug(f"Raw API response: {content[:200]}")

            # Clean up JSON formatting
            content = content.replace('```json', '').replace('```', '').strip()

            # Check if response is empty or "null"
            if not content or content.lower() == 'null' or content == '[]':
                logger.warning(f"Empty or null response for {disease_name}")
                return []

            treatments = json.loads(content)

            if not isinstance(treatments, list):
                logger.warning(f"Expected list, got: {type(treatments)}")
                return []

            logger.info(f"✅ Extracted {len(treatments)} treatments for {disease_name}")
            return treatments

        except json.JSONDecodeError as e:
            logger.warning(f"JSON parse error for {disease_name}: {e}")
            logger.warning(f"Content was: {content[:500]}")
            return []
        except Exception as e:
            logger.warning(f"AI extraction error for {disease_name}: {e}")
            return []

    def translate_treatments_to_portuguese(self, treatments, disease_name):
        """Translate treatments to Portuguese"""
        if not treatments:
            return treatments

        self._rate_limit()

        prompt = f"""
Translate these medical treatments for {disease_name} to Portuguese.
Keep the same structure but translate the "treatment" field to Portuguese.

INPUT:
{json.dumps(treatments, indent=2)}

Return the same JSON array with "treatment" translated to Portuguese:
"""

        try:
            response = self.anthropic.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=1000,
                messages=[{"role": "user", "content": prompt}]
            )

            content = response.content[0].text.strip()
            content = content.replace('```json', '').replace('```', '').strip()

            translated_treatments = json.loads(content)

            # Merge English and Portuguese
            result = []
            for i, treatment_en in enumerate(treatments):
                treatment_pt = translated_treatments[i] if i < len(translated_treatments) else treatment_en

                result.append({
                    'english': treatment_en.get('treatment', ''),
                    'portuguese': treatment_pt.get('treatment', treatment_en.get('treatment', '')),
                    'category': treatment_en.get('category', 'medication'),
                    'is_primary': treatment_en.get('is_primary', False)
                })

            logger.info(f"✅ Translated {len(result)} treatments to Portuguese")
            return result

        except Exception as e:
            logger.warning(f"Translation error: {e}")
            # Return English only if translation fails
            return [{
                'english': t.get('treatment', ''),
                'portuguese': t.get('treatment', ''),
                'category': t.get('category', 'medication'),
                'is_primary': t.get('is_primary', False)
            } for t in treatments]

    def insert_treatments(self, disease_id, treatments):
        """Insert treatments into database"""
        if not treatments:
            return 0

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        inserted_count = 0
        for treatment in treatments:
            try:
                cursor.execute("""
                    INSERT INTO treatments
                    (disease_id, treatment_english, treatment_portuguese, is_primary_treatment, category)
                    VALUES (?, ?, ?, ?, ?)
                """, (
                    disease_id,
                    treatment.get('english', ''),
                    treatment.get('portuguese', ''),
                    treatment.get('is_primary', False),
                    treatment.get('category', 'medication')
                ))
                inserted_count += 1
            except Exception as e:
                logger.warning(f"Failed to insert treatment: {e}")

        conn.commit()
        conn.close()

        return inserted_count

    def process_all_diseases(self, limit=None):
        """Process all diseases and extract treatments"""
        diseases = self.get_diseases_without_treatments()

        if limit:
            diseases = diseases[:limit]
            logger.info(f"Processing first {limit} diseases (testing mode)")

        total_diseases = len(diseases)
        processed = 0
        treatments_added = 0

        for i, disease in enumerate(diseases):
            logger.info(f"\n{'='*60}")
            logger.info(f"Processing {i+1}/{total_diseases}: {disease['name_english']}")
            logger.info(f"{'='*60}")

            # Search PDF for disease
            disease_text = self.search_pdf_for_disease(disease['name_english'])

            if not disease_text:
                logger.info(f"Disease not in PDF, using AI medical knowledge for {disease['name_english']}")
                # Use a generic medical description as context
                disease_text = f"{disease['name_english']} - {disease['category']} condition. Provide standard medical treatments."

            # Extract treatments with AI
            treatments_en = self.extract_treatments_with_ai(disease['name_english'], disease_text)

            if not treatments_en:
                logger.warning(f"No treatments extracted for {disease['name_english']}")
                processed += 1
                continue

            # Translate to Portuguese
            treatments = self.translate_treatments_to_portuguese(treatments_en, disease['name_english'])

            # Insert into database
            count = self.insert_treatments(disease['id'], treatments)
            treatments_added += count
            processed += 1

            logger.info(f"✅ Added {count} treatments for {disease['name_english']}")
            logger.info(f"Progress: {processed}/{total_diseases} diseases, {treatments_added} total treatments")

        logger.info(f"\n{'='*60}")
        logger.info(f"COMPLETED!")
        logger.info(f"Processed: {processed} diseases")
        logger.info(f"Treatments added: {treatments_added}")
        logger.info(f"{'='*60}")

def main():
    # Configuration
    DB_PATH = "../ios-app/Med.IA4.0_CLAUDE/medical_conditions.sqlite"
    PDF_PATH = "../pdfs/disease-handbook-complete.pdf"

    # Get API key from environment
    api_key = os.getenv('ANTHROPIC_API_KEY')
    if not api_key:
        logger.error("ANTHROPIC_API_KEY not found in environment")
        logger.error("Please set it in ../config/.env")
        sys.exit(1)

    # Create extractor
    extractor = TreatmentExtractor(DB_PATH, PDF_PATH, api_key)

    # Process diseases
    # Use limit=10 for testing, remove limit for full run
    print("\n" + "="*60)
    print("TREATMENT EXTRACTION TOOL")
    print("="*60)
    print(f"This will extract treatments for all 447 diseases")
    print(f"Estimated time: 15-20 minutes (with API delays)")
    print("="*60)

    response = input("\nProcess ALL diseases? (yes/test/no): ").strip().lower()

    if response == 'test':
        logger.info("TEST MODE: Processing first 10 diseases")
        extractor.process_all_diseases(limit=10)
    elif response == 'yes':
        logger.info("FULL MODE: Processing all diseases")
        extractor.process_all_diseases()
    else:
        logger.info("Cancelled by user")
        sys.exit(0)

if __name__ == '__main__':
    main()
