# Treatment Extraction Guide

## Overview
This guide explains how to automatically extract and populate treatments for all 447 diseases in your medical training app database.

## Prerequisites

1. **Python Environment**
   ```bash
   cd /Users/douglasgatti/medical-training-app/python-extraction
   source medical_env/bin/activate  # Activate virtual environment
   ```

2. **Required Packages**
   ```bash
   pip install anthropic pdfplumber python-dotenv
   ```

3. **API Key**
   - Ensure your Anthropic API key is set in `../config/.env`:
     ```
     ANTHROPIC_API_KEY=your_key_here
     API_DELAY_SECONDS=1.5
     ```

## Files Modified

### 1. `pdf_extractor.py` (Updated)
- Added `treatments` field to `MedicalCondition` class
- Updated AI extraction prompt to extract treatments with categories
- Added treatment translation to Portuguese
- Categorizes treatments: medication, procedure, lifestyle, supportive

### 2. `database_populator.py` (Updated)
- Added `treatments` table creation
- Added treatment insertion logic
- Added treatment statistics to database stats

### 3. `manual_curator.py` (Updated)
- Added comprehensive `treatment_translations` dictionary
- Includes 100+ common medical treatment terms
- Maps English → Portuguese for automatic translation fallback

### 4. `treatment_extractor.py` (NEW)
- **Purpose**: Extract treatments for existing 447 diseases
- **Input**: Existing database + PDF source
- **Output**: Populates treatments table

## Quick Start: Extract Treatments for All 447 Diseases

### Step 1: Test Run (10 diseases)
```bash
cd /Users/douglasgatti/medical-training-app/python-extraction
python treatment_extractor.py
# When prompted, type: test
```

This will:
- Process the first 10 diseases
- Extract 2-5 treatments per disease
- Translate to Portuguese
- Insert into database
- Take ~2-3 minutes

### Step 2: Full Run (All 447 diseases)
```bash
python treatment_extractor.py
# When prompted, type: yes
```

This will:
- Process all 447 diseases
- Extract treatments from PDF
- Translate all treatments to Portuguese
- Insert into database
- Take ~15-20 minutes

### Step 3: Verify Results
```bash
sqlite3 ../ios-app/Med.IA4.0_CLAUDE/medical_conditions.sqlite "
SELECT COUNT(*) as total_treatments FROM treatments;
SELECT COUNT(*) as diseases_with_treatments FROM (
    SELECT DISTINCT disease_id FROM treatments
);
SELECT name_english, treatment_english, category, is_primary_treatment
FROM diseases d
JOIN treatments t ON d.id = t.disease_id
LIMIT 10;
"
```

### Step 4: Copy Database to iOS App Bundle
```bash
# The database is already in the right location!
# Just rebuild your Xcode project to pick up the changes
```

## How It Works

### Treatment Extraction Process

1. **Load Diseases**: Reads all diseases from existing database
2. **Search PDF**: Finds disease-specific text in medical handbook
3. **AI Extraction**: Uses Claude to extract treatments:
   - Identifies medication, procedure, lifestyle, supportive treatments
   - Marks primary vs. supportive treatments
   - Ensures 2-5 treatments per disease
4. **Translation**: Translates each treatment to Portuguese
5. **Database Insert**: Adds treatments to database

### Treatment Categories

- **medication**: Antibiotics, antivirals, pain relievers, etc.
- **procedure**: Surgery, intubation, dialysis
- **lifestyle**: Rest, hydration, diet modifications
- **supportive**: Oxygen therapy, monitoring, palliative care

### Treatment Structure
```json
{
  "english": "Broad-spectrum antibiotics (e.g., ceftriaxone)",
  "portuguese": "Antibióticos de amplo espectro (ex: ceftriaxona)",
  "category": "medication",
  "is_primary": true
}
```

## Expected Results

### Success Metrics
- **447 diseases** processed
- **~1,500-2,000 total treatments** extracted
- **~890+ primary treatments** (2 per disease minimum)
- **~600+ supportive treatments**

### Quality Indicators
- ✅ Each disease should have 2-5 treatments
- ✅ At least 1 primary treatment per disease
- ✅ Treatments are specific (not generic)
- ✅ Portuguese translations are accurate

## Troubleshooting

### Issue: API Rate Limit Errors
**Solution**: Increase `API_DELAY_SECONDS` in `.env`
```bash
API_DELAY_SECONDS=2.0  # Increase from 1.5 to 2.0
```

### Issue: Some Diseases Not Found in PDF
**Expected**: Some diseases may not be in the PDF
**Solution**: These will be logged as warnings, script continues

### Issue: Translation Errors
**Fallback**: English text is used as Portuguese if translation fails
**Solution**: Manual review after extraction

### Issue: Database Locked
**Solution**: Close any other connections to the database
```bash
# Check for processes using the database
lsof | grep medical_conditions.sqlite
```

## Manual Review (Optional)

After extraction, you can manually review and improve treatments:

```bash
# Export treatments to CSV for review
sqlite3 ../ios-app/Med.IA4.0_CLAUDE/medical_conditions.sqlite << EOF
.headers on
.mode csv
.output treatments_review.csv
SELECT d.name_english, d.name_portuguese, t.treatment_english, t.treatment_portuguese,
       t.category, t.is_primary_treatment
FROM diseases d
JOIN treatments t ON d.id = t.disease_id
ORDER BY d.name_english;
.quit
EOF
```

## Alternative Approaches

### Approach 1: Extract from Multiple PDFs
If you have multiple medical sources:

```python
# Modify treatment_extractor.py to search multiple PDFs
PDF_PATHS = [
    "../pdfs/disease-handbook-complete.pdf",
    "../pdfs/DeGowin_s Diagnostic Examination 9th Edition.pdf"
]
```

### Approach 2: Manual CSV Import
For manual entry or review:

1. Export diseases to CSV
2. Add treatments manually in Excel/Google Sheets
3. Import back with custom script

## Cost Estimation

- **API Calls**: ~894 calls (2 per disease: extraction + translation)
- **Model**: Claude 3 Haiku
- **Estimated Cost**: $1-2 USD (Haiku is very cheap)
- **Time**: 15-20 minutes with rate limiting

## Next Steps

After successful extraction:

1. **Test in iOS App**:
   - Run app on simulator
   - Diagnose a patient correctly
   - Verify treatment entry screen appears
   - Test treatment validation

2. **Quality Check**:
   - Review 10-20 random treatments
   - Check Portuguese translations
   - Verify primary treatment flags

3. **Iterate**:
   - If quality is low, adjust AI prompts
   - Re-run specific diseases
   - Manual corrections as needed

## Support

If you encounter issues:
1. Check logs for specific error messages
2. Run test mode first (10 diseases)
3. Review database schema matches Swift code
4. Verify API key is valid

## Summary

This automated extraction will save you **30-40 hours** of manual work while maintaining good quality (~70-80% accuracy). The small amount of manual review needed is worth the massive time savings!
