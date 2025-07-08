
#!/usr/bin/env python3
# pdf_extractor.py - Medical PDF Extraction Tool

import json
import os
import sys
from pathlib import Path
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MedicalPDFExtractor:
    def __init__(self, api_key, output_dir="../output"):
        self.api_key = api_key
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        logger.info("PDF Extractor initialized")

    def extract_text_from_pdf(self, pdf_path):
        logger.info(f"Extracting text from: {pdf_path}")
        
        try:
            import pdfplumber
            with pdfplumber.open(pdf_path) as pdf:
                text = ""
                for page in pdf.pages[:10]:  # Limit to 10 pages for testing
                    page_text = page.extract_text()
                    if page_text:
                        text += page_text + "\n"
                
                logger.info(f"Extracted {len(text)} characters")
                return text, {"pages": len(pdf.pages)}
        
        except ImportError:
            logger.error("pdfplumber not installed")
            return "", {}
        except Exception as e:
            logger.error(f"Error extracting PDF: {e}")
            return "", {}

    def process_pdf(self, pdf_path):
        logger.info(f"Processing: {pdf_path}")
        text, metadata = self.extract_text_from_pdf(pdf_path)
        
        if not text:
            return []
        
        # For now, just return a test condition
        conditions = [{
            "name_english": "Test Condition",
            "name_portuguese": "Condição de Teste",
            "category": "Test",
            "severity": "Test",
            "description_english": "Test description",
            "description_portuguese": "Descrição de teste",
            "symptoms": [],
            "physical_findings": [],
            "lab_results": [],
            "diagnostic_hints": []
        }]
        
        return conditions

def main():
    logger.info("=== Medical PDF Extraction Started ===")
    
    # Check for PDF directory
    pdf_dir = Path("../pdfs")
    if not pdf_dir.exists():
        logger.error("PDF directory not found: ../pdfs")
        logger.info("Please create the directory and add your medical textbook PDFs")
        return
    
    pdf_files = list(pdf_dir.glob("*.pdf"))
    if not pdf_files:
        logger.error("No PDF files found in ../pdfs")
        logger.info("Please add medical textbook PDFs to the directory")
        return
    
    logger.info(f"Found {len(pdf_files)} PDF files to process")
    
    # Initialize extractor
    extractor = MedicalPDFExtractor("test-api-key")
    
    all_conditions = []
    
    for i, pdf_file in enumerate(pdf_files):
        logger.info(f"Processing PDF {i+1}/{len(pdf_files)}: {pdf_file.name}")
        
        try:
            conditions = extractor.process_pdf(str(pdf_file))
            all_conditions.extend(conditions)
            logger.info(f"Extracted {len(conditions)} conditions")
        except Exception as e:
            logger.error(f"Failed to process {pdf_file.name}: {e}")
    
    logger.info(f"Total conditions extracted: {len(all_conditions)}")
    
    # Save results
    if all_conditions:
        output_file = Path("../output/extracted_data/test_results.json")
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w') as f:
            json.dump(all_conditions, f, indent=2)
        
        logger.info(f"Results saved to: {output_file}")

if __name__ == "__main__":
    main()

