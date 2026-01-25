#!/usr/bin/env python3
# manual_curator.py - Manual review tools for extracted medical data

import json
import pandas as pd
from pathlib import Path
import logging
import uuid
import re

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ManualReviewTool:
    def __init__(self, input_dir="../output/extracted_data", output_dir="../output/reviewed_data"):
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Translation dictionaries
        self.category_translations = {
            'Cardiovascular': 'Cardiovascular',
            'Respiratory': 'Respiratório',
            'Gastrointestinal': 'Gastrointestinal',
            'Neurological': 'Neurológico',
            'Musculoskeletal': 'Musculoesquelético',
            'Dermatological': 'Dermatológico',
            'Endocrine': 'Endócrino',
            'Infectious Disease': 'Doença Infecciosa',
            'Infectious': 'Infeccioso',
            'Hematological': 'Hematológico',
            'Oncological': 'Oncológico',
            'Psychiatric': 'Psiquiátrico',
            'Ophthalmological': 'Oftalmológico',
            'ENT': 'Otorrinolaringológico',
            'Urological': 'Urológico',
            'Gynecological': 'Ginecológico',
            'Pediatric': 'Pediátrico',
            'Emergency': 'Emergência',
            'General': 'Geral'
        }

        self.severity_translations = {
            'Mild': 'Leve',
            'Moderate': 'Moderado',
            'Severe': 'Grave',
            'Critical': 'Crítico',
            'Chronic': 'Crônico',
            'Acute': 'Agudo',
            'Life-threatening': 'Potencialmente fatal',
            'Variable': 'Variável'
        }

        # Medical terms translation dictionary
        self.medical_translations = {
            # Temperature/Fever terms
            'fever': 'febre',
            'temperature': 'temperatura',
            'febrile': 'febril',
            'pyrexia': 'pirexia',
            'hyperthermia': 'hipertermia',
            'hypothermia': 'hipotermia',
            'breaks': 'cede',
            'occurring': 'ocorrendo',
            'immediately': 'imediatamente',
            'after': 'após',
            'characteristic': 'característico',
            'rash': 'erupção cutânea',

            # Blood test terms
            'blood': 'sangue',
            'evaluation': 'avaliação',
            'healthcare provider': 'profissional de saúde',
            'assess': 'avaliar',
            'bacterial infection': 'infecção bacteriana',
            'skin scraping': 'raspagem da pele',
            'culture': 'cultura',
            'may take': 'pode fazer',
            'for a': 'para uma',
            'laboratory tests': 'exames laboratoriais',
            'laboratory findings': 'achados laboratoriais',
            'specific': 'específico',
            'mentioned': 'mencionado',
            'required': 'necessário',
            'diagnosis': 'diagnóstico',
            'none specified': 'nenhum especificado',
            'no specific': 'nenhum específico',
            'physical findings': 'achados físicos',
            'microscopic findings': 'achados microscópicos',
            'stool culture': 'cultura de fezes',
            'throat culture': 'cultura de garganta',
            'bacterial': 'bacteriano',
            'viral': 'viral',
            'infection': 'infecção',
            'symptoms': 'sintomas',
            'generally': 'geralmente',
            'appear': 'aparecem',
            'examination': 'exame',
            'microscopic': 'microscópico',
            'discharge': 'secreção',
            'white': 'branco',
            'color': 'cor',
            'swollen': 'inchado',
            'tonsils': 'amígdalas',
            'neck': 'pescoço',
            'glands': 'glândulas',
            'vaccination': 'vacinação',
            'series': 'série',
            'parasites': 'parasitas',
            'people': 'pessoas',
            'serious': 'sério',
            'illness': 'doença',
            'seek': 'procurar',
            'medical attention': 'atenção médica',
            'virus': 'vírus',
            'live': 'viver',
            'provided': 'fornecido',
            'usually': 'geralmente',
            'between': 'entre',
            'weeks': 'semanas',
            'months': 'meses',
            'penetration': 'penetração',
            'skin': 'pele',
            'teeth': 'dentes',
            'infected': 'infectado',
            'animal': 'animal',
            'poses': 'representa',
            'potential': 'potencial',
            'risk': 'risco',
            'infectious': 'infeccioso',
            'saliva': 'saliva',
            'brain': 'cérebro',
            'spinal cord': 'medula espinhal',
            'tissue': 'tecido',
            'rabid': 'raivoso',
            'coming': 'vindo',
            'contact': 'contato',
            'sample': 'amostra',
            'collected': 'coletada',
            'analysed': 'analisada',
            'confirm': 'confirmar',
            'based': 'baseado',
            'child': 'criança',
            'visible': 'visível',
            'eggs': 'ovos',
            'small': 'pequeno',
            'number': 'número',
            'cause': 'causar',
            'new': 'novo',
            'onset': 'início',
            'fatigue': 'fadiga',
            'related': 'relacionado',
            'exertion': 'esforço',
            'relieved': 'aliviado',
            'rest': 'descanso',
            'resulting': 'resultando',
            'substantial': 'substancial',
            'limitation': 'limitação',
            'daily': 'diário',
            'activities': 'atividades',
            'elevated': 'elevado',
            'copper': 'cobre',
            'levels': 'níveis',
            'urine': 'urina',
            'destruction': 'destruição',
            'structures': 'estruturas',
            'including': 'incluindo',
            'mouth': 'boca',
            'sinuses': 'seios',
            'eyes': 'olhos',

            # General medical terms
            'chest pain': 'dor no peito',
            'shortness of breath': 'falta de ar',
            'elevated': 'elevado',
            'normal': 'normal',
            'abnormal': 'anormal',
            'positive': 'positivo',
            'negative': 'negativo',
            'test': 'teste',
            'result': 'resultado',
            'finding': 'achado',
            'present': 'presente',
            'absent': 'ausente'
        }

        # Treatment translations dictionary
        self.treatment_translations = {
            # Medications - Antibiotics
            'antibiotics': 'antibióticos',
            'broad-spectrum antibiotics': 'antibióticos de amplo espectro',
            'intravenous antibiotics': 'antibióticos intravenosos',
            'oral antibiotics': 'antibióticos orais',
            'amoxicillin': 'amoxicilina',
            'penicillin': 'penicilina',
            'azithromycin': 'azitromicina',
            'ciprofloxacin': 'ciprofloxacina',
            'doxycycline': 'doxiciclina',
            'cephalosporins': 'cefalosporinas',

            # Medications - Pain Management
            'pain management': 'controle da dor',
            'pain relief': 'alívio da dor',
            'analgesics': 'analgésicos',
            'NSAIDs': 'AINEs',
            'ibuprofen': 'ibuprofeno',
            'acetaminophen': 'paracetamol',
            'paracetamol': 'paracetamol',
            'morphine': 'morfina',
            'opioids': 'opioides',

            # Medications - Antivirals
            'antiviral': 'antiviral',
            'antivirals': 'antivirais',
            'acyclovir': 'aciclovir',
            'oseltamivir': 'oseltamivir',
            'tamiflu': 'tamiflu',

            # Medications - Other
            'corticosteroids': 'corticosteroides',
            'steroids': 'esteroides',
            'prednisone': 'prednisona',
            'antihistamines': 'anti-histamínicos',
            'insulin': 'insulina',
            'beta-blockers': 'betabloqueadores',
            'statins': 'estatinas',
            'aspirin': 'aspirina',
            'anticoagulants': 'anticoagulantes',
            'diuretics': 'diuréticos',
            'bronchodilators': 'broncodilatadores',
            'inhalers': 'inaladores',
            'epinephrine': 'epinefrina',
            'adrenaline': 'adrenalina',

            # Medications - Migraine specific
            'triptans': 'triptanos',
            'sumatriptan': 'sumatriptano',

            # Procedures - Surgery
            'surgery': 'cirurgia',
            'emergency surgery': 'cirurgia de emergência',
            'surgical intervention': 'intervenção cirúrgica',
            'appendectomy': 'apendicectomia',
            'cholecystectomy': 'colecistectomia',
            'laparoscopy': 'laparoscopia',
            'open surgery': 'cirurgia aberta',
            'incision and drainage': 'incisão e drenagem',
            'biopsy': 'biópsia',

            # Procedures - Medical
            'intubation': 'intubação',
            'mechanical ventilation': 'ventilação mecânica',
            'dialysis': 'diálise',
            'transfusion': 'transfusão',
            'blood transfusion': 'transfusão sanguínea',
            'intravenous fluids': 'fluidos intravenosos',
            'IV fluids': 'fluidos IV',
            'catheterization': 'cateterização',
            'drainage': 'drenagem',

            # Supportive Care
            'supportive care': 'cuidados de suporte',
            'oxygen therapy': 'oxigenoterapia',
            'supplemental oxygen': 'oxigênio suplementar',
            'monitoring': 'monitoramento',
            'observation': 'observação',
            'bed rest': 'repouso no leito',
            'hospitalization': 'hospitalização',
            'ICU admission': 'internação em UTI',
            'intensive care': 'cuidados intensivos',

            # Lifestyle/Self-care
            'rest': 'repouso',
            'hydration': 'hidratação',
            'fluid intake': 'ingestão de líquidos',
            'increase fluid intake': 'aumentar ingestão de líquidos',
            'drink plenty of fluids': 'beber bastante líquido',
            'diet modification': 'modificação dietética',
            'dietary changes': 'mudanças na dieta',
            'low-fat diet': 'dieta com baixo teor de gordura',
            'high-fiber diet': 'dieta rica em fibras',
            'exercise': 'exercício',
            'physical therapy': 'fisioterapia',
            'rehabilitation': 'reabilitação',
            'lifestyle changes': 'mudanças no estilo de vida',
            'avoid triggers': 'evitar gatilhos',
            'smoking cessation': 'cessação do tabagismo',
            'weight loss': 'perda de peso',

            # Environment modifications
            'dark quiet room': 'quarto escuro e silencioso',
            'rest in dark room': 'descanso em quarto escuro',
            'avoid bright lights': 'evitar luzes brilhantes',
            'cold compress': 'compressa fria',
            'warm compress': 'compressa quente',
            'ice pack': 'bolsa de gelo',
            'heat therapy': 'termoterapia',

            # Vaccination
            'vaccination': 'vacinação',
            'immunization': 'imunização',
            'vaccine': 'vacina',

            # Emergency treatments
            'CPR': 'RCP (reanimação cardiopulmonar)',
            'defibrillation': 'desfibrilação',
            'emergency treatment': 'tratamento de emergência',

            # Conditional phrases
            'if needed': 'se necessário',
            'if indicated': 'se indicado',
            'if hypoxic': 'se hipóxico',
            'as needed': 'conforme necessário',
            'for severe cases': 'para casos graves',
            'in severe cases': 'em casos graves',
            'may require': 'pode requerer',

            # Conjunctions and prepositions
            'and': 'e',
            'or': 'ou',
            'with': 'com',
            'for': 'para',
            'to': 'para'
        }

        # Keywords for categorizing findings into test types
        self.test_keywords = {
            'temperature': ['fever', 'temperature', 'temp', 'febrile', 'pyrexia', 'hyperthermia', 'hypothermia', '°c', '°f', 'celsius', 'fahrenheit'],
            'xray': ['x-ray', 'xray', 'chest x-ray', 'radiograph', 'chest film', 'cxr', 'pneumonia', 'consolidation', 'infiltrate'],
            'blood_test': ['blood', 'CBC', 'WBC', 'hemoglobin', 'hematocrit', 'platelet', 'glucose', 'sodium', 'potassium', 'creatinine', 'BUN', 'liver enzymes', 'AST', 'ALT', 'bilirubin'],
            'ecg': ['ECG', 'EKG', 'electrocardiogram', 'ST elevation', 'ST depression', 'Q waves', 'arrhythmia', 'atrial fibrillation', 'heart rhythm'],
            'ultrasound': ['ultrasound', 'echo', 'echocardiogram', 'doppler', 'cardiac ultrasound', 'abdominal ultrasound'],
            'mri': ['MRI', 'magnetic resonance', 'T1', 'T2', 'FLAIR', 'contrast enhancement'],
            'ct_scan': ['CT', 'computed tomography', 'CT scan', 'contrast CT', 'CT angiogram', 'CTA'],
            'urinalysis': ['urine', 'urinalysis', 'proteinuria', 'hematuria', 'specific gravity', 'urine culture'],
            'biopsy': ['biopsy', 'histology', 'pathology', 'tissue sample', 'cytology']
        }

        # Normal baseline values for when tests don't show abnormalities
        self.normal_baseline_values = {
            'temperature': {
                'english': 'Temperature 36.5°C (97.7°F) - Normal body temperature',
                'portuguese': 'Temperatura 36,5°C (97,7°F) - Temperatura corporal normal'
            },
            'blood_pressure': {
                'english': 'Blood pressure 120/80 mmHg - Normal blood pressure',
                'portuguese': 'Pressão arterial 120/80 mmHg - Pressão arterial normal'
            },
            'heart_rate': {
                'english': 'Heart rate 72 bpm - Normal resting heart rate',
                'portuguese': 'Frequência cardíaca 72 bpm - Frequência cardíaca normal em repouso'
            },
            'respiratory_rate': {
                'english': 'Respiratory rate 16 breaths/min - Normal breathing rate',
                'portuguese': 'Frequência respiratória 16 respirações/min - Frequência respiratória normal'
            },
            'blood_test': {
                'english': 'Complete Blood Count: WBC 7,000/μL, RBC 4.5M/μL, Hemoglobin 14g/dL, Platelets 250,000/μL - All values within normal limits',
                'portuguese': 'Hemograma Completo: Leucócitos 7.000/μL, Hemácias 4,5M/μL, Hemoglobina 14g/dL, Plaquetas 250.000/μL - Todos os valores dentro dos limites normais'
            },
            'basic_metabolic_panel': {
                'english': 'Basic Metabolic Panel: Glucose 90mg/dL, Sodium 140mEq/L, Potassium 4.0mEq/L, Creatinine 1.0mg/dL - Normal metabolic function',
                'portuguese': 'Painel Metabólico Básico: Glicose 90mg/dL, Sódio 140mEq/L, Potássio 4,0mEq/L, Creatinina 1,0mg/dL - Função metabólica normal'
            },
            'liver_function': {
                'english': 'Liver Function Tests: ALT 25 U/L, AST 30 U/L, Bilirubin 1.0mg/dL - Normal liver function',
                'portuguese': 'Testes de Função Hepática: ALT 25 U/L, AST 30 U/L, Bilirrubina 1,0mg/dL - Função hepática normal'
            },
            'xray': {
                'english': 'Chest X-ray: Clear lung fields, normal heart size, no acute findings - Normal chest X-ray',
                'portuguese': 'Raio-X de Tórax: Campos pulmonares limpos, tamanho cardíaco normal, sem achados agudos - Raio-X de tórax normal'
            },
            'abdominal_xray': {
                'english': 'Abdominal X-ray: Normal bowel gas pattern, no obstruction or free air - Normal abdominal X-ray',
                'portuguese': 'Raio-X Abdominal: Padrão normal de gases intestinais, sem obstrução ou ar livre - Raio-X abdominal normal'
            },
            'ecg': {
                'english': 'ECG: Normal sinus rhythm, rate 72 bpm, normal PR interval, normal QRS, normal T waves - Normal ECG',
                'portuguese': 'ECG: Ritmo sinusal normal, frequência 72 bpm, intervalo PR normal, QRS normal, ondas T normais - ECG normal'
            },
            'ultrasound_abdominal': {
                'english': 'Abdominal Ultrasound: Normal liver, gallbladder, pancreas, spleen, and kidneys - No abnormalities detected',
                'portuguese': 'Ultrassom Abdominal: Fígado, vesícula biliar, pâncreas, baço e rins normais - Nenhuma anormalidade detectada'
            },
            'ultrasound_cardiac': {
                'english': 'Echocardiogram: Normal left ventricular function, EF 60%, no wall motion abnormalities, normal valves',
                'portuguese': 'Ecocardiograma: Função ventricular esquerda normal, FE 60%, sem anormalidades de movimento parietal, válvulas normais'
            },
            'ct_scan_head': {
                'english': 'Head CT: No acute intracranial abnormality, normal brain parenchyma, no hemorrhage or mass effect',
                'portuguese': 'TC de Crânio: Sem anormalidade intracraniana aguda, parênquima cerebral normal, sem hemorragia ou efeito de massa'
            },
            'ct_scan_chest': {
                'english': 'Chest CT: Normal lung parenchyma, no pulmonary embolism, normal mediastinal structures',
                'portuguese': 'TC de Tórax: Parênquima pulmonar normal, sem embolia pulmonar, estruturas mediastinais normais'
            },
            'ct_scan_abdomen': {
                'english': 'Abdominal CT: Normal solid organs, no free fluid, normal bowel, no masses or collections',
                'portuguese': 'TC Abdominal: Órgãos sólidos normais, sem líquido livre, intestino normal, sem massas ou coleções'
            },
            'mri_brain': {
                'english': 'Brain MRI: Normal brain parenchyma, no acute infarct, no hemorrhage, normal vascular flow voids',
                'portuguese': 'RM de Crânio: Parênquima cerebral normal, sem infarto agudo, sem hemorragia, vazios de fluxo vascular normais'
            },
            'urinalysis': {
                'english': 'Urinalysis: Clear yellow urine, specific gravity 1.020, no protein, no glucose, no blood, no bacteria - Normal urine',
                'portuguese': 'Exame de Urina: Urina amarelo claro, densidade 1.020, sem proteína, sem glicose, sem sangue, sem bactérias - Urina normal'
            },
            'stool_analysis': {
                'english': 'Stool Analysis: Normal brown color, no blood, no mucus, no parasites, normal consistency - Normal stool',
                'portuguese': 'Exame de Fezes: Cor marrom normal, sem sangue, sem muco, sem parasitas, consistência normal - Fezes normais'
            },
            'throat_culture': {
                'english': 'Throat Culture: Normal oral flora, no pathogenic bacteria - Negative for streptococcus',
                'portuguese': 'Cultura de Garganta: Flora oral normal, sem bactérias patogênicas - Negativo para estreptococos'
            },
            'biopsy': {
                'english': 'Tissue Biopsy: Normal tissue architecture, no malignant cells, no inflammation - Benign findings',
                'portuguese': 'Biópsia de Tecido: Arquitetura tecidual normal, sem células malignas, sem inflamação - Achados benignos'
            }
        }

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
    
    def categorize_finding(self, finding_text, test_keywords):
        """Categorize a finding into the appropriate test type based on keywords"""
        finding_lower = finding_text.lower()
        matches = {}

        for test_type, keywords in test_keywords.items():
            for keyword in keywords:
                if keyword.lower() in finding_lower:
                    if test_type not in matches:
                        matches[test_type] = []
                    matches[test_type].append(finding_text)
                    break

        # If no specific match found, categorize as 'other_tests'
        if not matches:
            matches['other_tests'] = [finding_text]

        return matches

    def should_show_normal_values(self, condition, test_type):
        """Determine if a condition would realistically show normal values for a given test type"""
        condition_name = condition.get('name_english', '').lower()
        category = condition.get('category', '').lower()
        severity = condition.get('severity', '').lower()

        # Conditions that typically don't affect basic vital signs
        non_affecting_conditions = [
            'common cold', 'minor skin conditions', 'mild allergies',
            'minor cuts', 'bruises', 'mild headaches', 'hay fever',
            'mild dermatitis', 'minor sprains', 'mild gastritis'
        ]

        # Test-specific logic
        if test_type == 'temperature':
            # Show normal temp unless condition typically causes fever
            fever_conditions = ['infection', 'flu', 'pneumonia', 'sepsis', 'meningitis', 'hepatitis']
            return not any(fever_cond in condition_name for fever_cond in fever_conditions)

        elif test_type == 'blood_test':
            # Show normal blood work for minor conditions
            return any(minor in condition_name for minor in non_affecting_conditions)

        elif test_type == 'xray':
            # Show normal chest X-ray unless respiratory/cardiac condition
            affecting_categories = ['respiratory', 'cardiovascular']
            chest_conditions = ['pneumonia', 'tuberculosis', 'lung', 'heart', 'chest']
            return category not in affecting_categories and not any(chest in condition_name for chest in chest_conditions)

        elif test_type == 'ecg':
            # Show normal ECG unless cardiac condition
            cardiac_conditions = ['heart', 'cardiac', 'arrhythmia', 'myocardial', 'angina']
            return not any(cardiac in condition_name for cardiac in cardiac_conditions)

        elif test_type == 'urinalysis':
            # Show normal urine unless urinary/kidney condition
            urinary_conditions = ['uti', 'kidney', 'bladder', 'urinary', 'nephritis']
            return not any(urinary in condition_name for urinary in urinary_conditions)

        elif test_type == 'ultrasound':
            # Show normal ultrasound for minor conditions
            return any(minor in condition_name for minor in non_affecting_conditions)

        elif test_type == 'ct_scan':
            # Show normal CT for minor conditions not requiring imaging
            return any(minor in condition_name for minor in non_affecting_conditions)

        elif test_type == 'mri':
            # Show normal MRI for conditions not requiring advanced imaging
            return any(minor in condition_name for minor in non_affecting_conditions)

        elif test_type == 'biopsy':
            # Only show normal biopsy for very minor skin conditions
            minor_skin = ['minor dermatitis', 'mild eczema', 'minor rash']
            return any(skin in condition_name for skin in minor_skin)

        # Default: show normal values for minor conditions
        return any(minor in condition_name for minor in non_affecting_conditions)

    def get_normal_baseline_value(self, test_type, language):
        """Get the appropriate normal baseline value for a test type and language"""
        # Map test types to baseline values
        baseline_map = {
            'temperature': 'temperature',
            'blood_test': 'blood_test',
            'xray': 'xray',
            'ecg': 'ecg',
            'ultrasound': 'ultrasound_abdominal',
            'ct_scan': 'ct_scan_chest',
            'mri': 'mri_brain',
            'urinalysis': 'urinalysis',
            'biopsy': 'biopsy'
        }

        baseline_key = baseline_map.get(test_type, test_type)

        if baseline_key in self.normal_baseline_values:
            return self.normal_baseline_values[baseline_key].get(language, '')

        # Fallback normal values
        fallback_values = {
            'english': f'Normal {test_type.replace("_", " ")} - No abnormalities detected',
            'portuguese': f'{test_type.replace("_", " ").title()} normal - Nenhuma anormalidade detectada'
        }

        return fallback_values.get(language, '')

    def translate_medical_text(self, text):
        """Translate English medical text to Portuguese using the medical dictionary"""
        if not text or text.strip() == '' or pd.isna(text):
            return text

        # Convert to string in case it's not already
        text = str(text)

        # If text is already mostly Portuguese or very short, return as is
        if len(text) < 3:
            return text

        # Check if text is already in Portuguese (contains Portuguese-specific characters or common Portuguese words)
        portuguese_indicators = ['ção', 'ões', 'ã', 'õ', 'ê', 'â', 'ô', 'á', 'é', 'í', 'ó', 'ú', 'ç']
        common_portuguese_words = ['para', 'com', 'por', 'em', 'de', 'da', 'do', 'na', 'no', 'um', 'uma', 'são', 'não']

        # If already Portuguese, return as is
        if any(indicator in text.lower() for indicator in portuguese_indicators) or \
           any(word in text.lower().split() for word in common_portuguese_words):
            return text

        # Start translation
        translated = text

        # Apply translations from dictionary (case-insensitive)
        for en_term, pt_term in sorted(self.medical_translations.items(), key=len, reverse=True):
            # Use case-insensitive replacement but preserve original case structure
            pattern = re.compile(re.escape(en_term), re.IGNORECASE)
            translated = pattern.sub(pt_term, translated)

        # Handle common English words not in medical dictionary
        common_translations = {
            'and': 'e',
            'or': 'ou',
            'the': 'o/a',
            'of': 'de',
            'in': 'em',
            'for': 'para',
            'with': 'com',
            'by': 'por',
            'from': 'de',
            'to': 'para',
            'is': 'é',
            'are': 'são',
            'was': 'foi',
            'were': 'foram',
            'can': 'pode',
            'may': 'pode',
            'should': 'deve',
            'will': 'vai',
            'would': 'faria',
            'has': 'tem',
            'have': 'ter',
            'had': 'tinha',
            'be': 'ser',
            'been': 'sido',
            'not': 'não',
            'no': 'não',
            'yes': 'sim',
            'if': 'se',
            'when': 'quando',
            'where': 'onde',
            'how': 'como',
            'what': 'o que',
            'who': 'quem',
            'which': 'qual',
            'that': 'que',
            'this': 'este/esta',
            'these': 'estes/estas',
            'those': 'aqueles/aquelas',
            'some': 'alguns',
            'all': 'todos',
            'any': 'qualquer',
            'more': 'mais',
            'most': 'maioria',
            'less': 'menos',
            'other': 'outro',
            'such': 'tal',
            'only': 'apenas',
            'also': 'também',
            'than': 'que',
            'very': 'muito',
            'well': 'bem',
            'still': 'ainda',
            'just': 'apenas'
        }

        # Apply common word translations with word boundaries
        for en_word, pt_word in common_translations.items():
            pattern = re.compile(r'\b' + re.escape(en_word) + r'\b', re.IGNORECASE)
            translated = pattern.sub(pt_word, translated)

        # Additional medical translations for common phrases
        phrase_translations = [
            ('children', 'crianças'),
            ('adults', 'adultos'),
            ('often', 'frequentemente'),
            ('among', 'entre'),
            ('more often', 'mais frequentemente'),
            ('laboratory tests mentioned', 'exames laboratoriais mencionados'),
            ('no specific laboratory tests', 'nenhum exame laboratorial específico'),
            ('jaundice', 'icterícia'),
            ('after the', 'após o'),
            ('dehydration', 'desidratação'),
            ('recommended', 'recomendado'),
            ('undercooked beef', 'carne bovina mal cozida'),
            ('especially ground beef', 'especialmente carne moída'),
            ('most common source', 'fonte mais comum'),
            ('high risk', 'alto risco'),
            ('living in', 'vivendo em'),
            ('visiting areas', 'visitando áreas'),
            ('disease is common', 'doença é comum'),
            ('work outside', 'trabalham ao ar livre'),
            ('participate in outdoor', 'participam em atividades ao ar livre'),
            ('recreational activities', 'atividades recreativas'),
            ('clinical diagnosis', 'diagnóstico clínico'),
            ('characteristic lesions', 'lesões características'),
            ('stool test', 'exame de fezes'),
            ('nucleic acid detection', 'detecção de ácido nucleico'),
            ('antigen test', 'teste de antígeno'),
            ('infection is usually diagnosed', 'infecção é geralmente diagnosticada'),
            ('earlier in children', 'mais cedo em crianças'),
            ('due to their immature', 'devido ao seu imaturo'),
            ('immune system', 'sistema imunológico'),
            ('rash occurring immediately', 'erupção cutânea ocorrendo imediatamente'),
            ('fever breaks', 'febre cede'),
            ('distinguishing from', 'distinguindo de'),
            ('hypertrophic cardiomyopathy', 'cardiomiopatia hipertrófica'),
            ('constrictive pericarditis', 'pericardite constritiva'),
            ('murmur augmented with valsalva', 'sopro aumentado com valsalva'),
            ('tenderness along the course', 'sensibilidade ao longo do curso'),
            ('affected vein', 'veia afetada'),
            ('imaging findings related', 'achados de imagem relacionados'),
            ('underlying condition', 'condição subjacente'),
            ('joint abnormalities', 'anormalidades articulares'),
            ('tendon tears', 'rupturas de tendão'),
            ('fractures', 'fraturas'),
            ('partial flexion', 'flexão parcial'),
            ('affected finger', 'dedo afetado'),
            ('obtain genital', 'obter genital'),
            ('rectal specimens', 'espécimes retais'),
            ('throat specimens', 'espécimes de garganta'),
            ('culture or', 'cultura ou'),
            ('polymerase chain reaction', 'reação em cadeia da polimerase'),
            ('testing of urine', 'teste de urina'),
            ('gonococccus', 'gonococo'),
            ('difficulty culturing', 'dificuldade em cultivar'),
            ('joints', 'articulações'),
            ('small amount', 'pequena quantidade')
        ]

        # Apply phrase translations (longer phrases first)
        for en_phrase, pt_phrase in sorted(phrase_translations, key=lambda x: len(x[0]), reverse=True):
            pattern = re.compile(re.escape(en_phrase), re.IGNORECASE)
            translated = pattern.sub(pt_phrase, translated)

        # Capitalize first letter of sentences and after periods
        sentences = re.split(r'([.!?])', translated)
        result = []
        for i, part in enumerate(sentences):
            if i % 2 == 0 and part.strip():  # Text parts (not punctuation)
                part = part.strip()
                if part:
                    part = part[0].upper() + part[1:] if len(part) > 1 else part.upper()
            result.append(part)

        return ''.join(result)

    def split_findings_by_type(self, findings_list):
        """Split findings into appropriate test categories"""
        categorized = {
            'temperature': [],
            'xray': [],
            'blood_test': [],
            'ecg': [],
            'ultrasound': [],
            'mri': [],
            'ct_scan': [],
            'urinalysis': [],
            'biopsy': [],
            'other_tests': []
        }

        for finding in findings_list:
            if isinstance(finding, dict):
                finding_text = finding.get('english', '')
            else:
                finding_text = str(finding)

            if finding_text.strip():
                matches = self.categorize_finding(finding_text, self.test_keywords)
                for test_type, matched_findings in matches.items():
                    categorized[test_type].extend(matched_findings)

        # Remove duplicates while preserving order
        for test_type in categorized:
            seen = set()
            categorized[test_type] = [x for x in categorized[test_type] if not (x in seen or seen.add(x))]

        return categorized

    def export_to_excel(self, conditions, output_filename="medical_conditions_for_review.xlsx"):
        logger.info(f"Exporting {len(conditions)} conditions to Excel")

        excel_data = []
        for condition in conditions:
            # Generate unique ID if not present
            patient_id = condition.get('patient_id', str(uuid.uuid4())[:8])

            # Get category and severity with translations
            category_en = condition.get('category', '')
            category_pt = self.category_translations.get(category_en, category_en)

            severity_en = condition.get('severity', '')
            severity_pt = self.severity_translations.get(severity_en, severity_en)

            row = {
                'patient_id': patient_id,
                'name_english': condition.get('name_english', ''),
                'nome_portuguese': condition.get('name_portuguese', ''),
                'category_english': category_en,
                'categoria_portuguese': category_pt,
                'severity_english': severity_en,
                'severidade_portuguese': severity_pt,
                'description_english': condition.get('description_english', ''),
                'descricao_portuguese': condition.get('description_portuguese', ''),
                'confidence': condition.get('extraction_confidence', 0),
            }
            
            # Flatten symptoms
            symptoms = condition.get('symptoms', [])
            chief_complaints_en = [s.get('english', '') for s in symptoms if s.get('is_chief')]
            chief_complaints_pt = [s.get('portuguese', '') for s in symptoms if s.get('is_chief')]
            other_symptoms_en = [s.get('english', '') for s in symptoms if not s.get('is_chief')]
            other_symptoms_pt = [s.get('portuguese', '') for s in symptoms if not s.get('is_chief')]

            row['chief_complaints_english'] = '; '.join(chief_complaints_en)
            row['queixas_principais_portuguese'] = '; '.join(chief_complaints_pt)
            row['other_symptoms_english'] = '; '.join(other_symptoms_en)
            row['outros_sintomas_portuguese'] = '; '.join(other_symptoms_pt)

            # Physical findings - translate if needed
            physical_findings_en = [f.get('english', '') for f in condition.get('physical_findings', [])]
            physical_findings_pt = [f.get('portuguese', '') for f in condition.get('physical_findings', [])]

            row['physical_findings_english'] = '; '.join(physical_findings_en)

            translated_physical_findings = []
            for i, finding_en in enumerate(physical_findings_en):
                if i < len(physical_findings_pt) and physical_findings_pt[i] and physical_findings_pt[i] != finding_en:
                    translated_physical_findings.append(physical_findings_pt[i])  # Use existing Portuguese
                else:
                    translated_physical_findings.append(self.translate_medical_text(finding_en))  # Translate

            row['achados_fisicos_portuguese'] = '; '.join(translated_physical_findings)

            # Process lab results and categorize them into specific test types
            all_lab_results = condition.get('lab_results', [])
            all_physical_findings = condition.get('physical_findings', [])
            all_diagnostic_hints = condition.get('diagnostic_hints', [])

            # Combine all findings for categorization
            all_findings = all_lab_results + all_physical_findings + all_diagnostic_hints
            categorized_findings = self.split_findings_by_type(all_findings)

            # Fill diagnostic test columns with categorized findings
            test_types_with_portuguese_names = {
                'temperature': 'temperatura',
                'xray': 'raio_x',
                'blood_test': 'exame_sangue',
                'ecg': 'ecg',
                'ultrasound': 'ultrassom',
                'mri': 'ressonancia',
                'ct_scan': 'tomografia',
                'urinalysis': 'exame_urina',
                'biopsy': 'biopsia',
                'other_tests': 'outros_exames'
            }

            for test_type, pt_name in test_types_with_portuguese_names.items():
                findings_en = categorized_findings.get(test_type, [])

                # If no specific findings, check if we should provide normal baseline values
                if not findings_en or (len(findings_en) == 1 and not findings_en[0].strip()):
                    # Determine if condition would affect this test type
                    should_show_normal = self.should_show_normal_values(condition, test_type)

                    if should_show_normal:
                        normal_value_en = self.get_normal_baseline_value(test_type, 'english')
                        normal_value_pt = self.get_normal_baseline_value(test_type, 'portuguese')

                        row[f'{test_type}_english'] = normal_value_en
                        row[f'{pt_name}_portuguese'] = normal_value_pt
                    else:
                        row[f'{test_type}_english'] = '; '.join(findings_en)
                        row[f'{pt_name}_portuguese'] = '; '.join(findings_en)
                else:
                    # Use existing findings and translate them
                    row[f'{test_type}_english'] = '; '.join(findings_en)

                    # Translate findings to Portuguese
                    findings_pt = []
                    for finding in findings_en:
                        if finding and finding.strip():  # Only translate non-empty findings
                            translated_finding = self.translate_medical_text(finding)
                            findings_pt.append(translated_finding)
                        else:
                            findings_pt.append(finding)  # Keep empty as empty

                    row[f'{pt_name}_portuguese'] = '; '.join(findings_pt)

            # Keep original lab results for reference and translate Portuguese version
            lab_results_en = [r.get('english', '') for r in condition.get('lab_results', [])]
            lab_results_pt = [r.get('portuguese', '') for r in condition.get('lab_results', [])]

            row['lab_results_english'] = '; '.join(lab_results_en)

            # If Portuguese lab results are empty/same as English, translate them
            translated_lab_results = []
            for i, result_en in enumerate(lab_results_en):
                if i < len(lab_results_pt) and lab_results_pt[i] and lab_results_pt[i] != result_en:
                    translated_lab_results.append(lab_results_pt[i])  # Use existing Portuguese
                else:
                    translated_lab_results.append(self.translate_medical_text(result_en))  # Translate

            row['resultados_laboratorio_portuguese'] = '; '.join(translated_lab_results)

            # Diagnostic hints - translate if needed
            diagnostic_hints_en = [h.get('english', '') for h in condition.get('diagnostic_hints', [])]
            diagnostic_hints_pt = [h.get('portuguese', '') for h in condition.get('diagnostic_hints', [])]

            row['diagnostic_hints_english'] = '; '.join(diagnostic_hints_en)

            translated_diagnostic_hints = []
            for i, hint_en in enumerate(diagnostic_hints_en):
                if i < len(diagnostic_hints_pt) and diagnostic_hints_pt[i] and diagnostic_hints_pt[i] != hint_en:
                    translated_diagnostic_hints.append(diagnostic_hints_pt[i])  # Use existing Portuguese
                else:
                    translated_diagnostic_hints.append(self.translate_medical_text(hint_en))  # Translate

            row['dicas_diagnosticas_portuguese'] = '; '.join(translated_diagnostic_hints)

            # Clinical hints/clues for when patient needs help
            clinical_hints = condition.get('clinical_hints', {})
            clinical_hints_en = clinical_hints.get('english', '')
            clinical_hints_pt = clinical_hints.get('portuguese', '')

            row['clinical_hints_english'] = clinical_hints_en

            if clinical_hints_pt and clinical_hints_pt != clinical_hints_en:
                row['dicas_clinicas_portuguese'] = clinical_hints_pt  # Use existing Portuguese
            else:
                row['dicas_clinicas_portuguese'] = self.translate_medical_text(clinical_hints_en)  # Translate
            
            excel_data.append(row)
        
        df = pd.DataFrame(excel_data)
        output_path = self.output_dir / output_filename

        # Create multiple sheets for better readability
        with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
            # Sheet 1: English Only (cleaner for English speakers)
            english_columns = ['patient_id'] + [col for col in df.columns if col.endswith('_english')] + ['confidence']
            df_english = df[english_columns].copy()
            df_english.to_excel(writer, sheet_name='English_Data', index=False)

            # Sheet 2: Portuguese Only (cleaner for Portuguese speakers)
            portuguese_columns = ['patient_id'] + [col for col in df.columns if col.endswith('_portuguese')] + ['confidence']
            df_portuguese = df[portuguese_columns].copy()
            df_portuguese.to_excel(writer, sheet_name='Portuguese_Data', index=False)

            # Sheet 3: All Data Combined (for cross-reference and debugging)
            df.to_excel(writer, sheet_name='All_Data_Combined', index=False)

            # Apply formatting for better readability
            for sheet_name in writer.sheets:
                worksheet = writer.sheets[sheet_name]

                # Auto-adjust column widths for readability
                for column in worksheet.columns:
                    max_length = 0
                    column = [cell for cell in column]
                    for cell in column:
                        try:
                            if len(str(cell.value)) > max_length:
                                max_length = len(str(cell.value))
                        except:
                            pass
                    adjusted_width = min(max_length + 2, 50)  # Cap at 50 characters
                    worksheet.column_dimensions[column[0].column_letter].width = adjusted_width

                # Freeze the header row and patient_id column for easier navigation
                worksheet.freeze_panes = 'B2'

                # Make headers bold and add background color for better visibility
                from openpyxl.styles import Font, PatternFill
                header_font = Font(bold=True)
                header_fill = PatternFill(start_color='E6E6FA', end_color='E6E6FA', fill_type='solid')  # Light purple

                for cell in worksheet[1]:  # First row (headers)
                    cell.font = header_font
                    cell.fill = header_fill

        logger.info(f"Excel file with 3 sheets created: {output_path}")
        logger.info("📊 Sheets created:")
        logger.info("  1. English_Data - Only English columns for easier English review")
        logger.info("  2. Portuguese_Data - Only Portuguese columns for easier Portuguese review")
        logger.info("  3. All_Data_Combined - Complete dataset for debugging")
        logger.info("✨ Features added: Auto-column sizing, frozen headers, bold headers")
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
                'patient_id': row.get('patient_id', str(uuid.uuid4())[:8]),
                'name_english': row.get('name_english', ''),
                'name_portuguese': row.get('name_portuguese', ''),
                'category': row.get('category_english', ''),
                'category_portuguese': row.get('category_portuguese', ''),
                'severity': row.get('severity_english', ''),
                'severity_portuguese': row.get('severity_portuguese', ''),
                'description_english': row.get('description_english', ''),
                'description_portuguese': row.get('description_portuguese', ''),
                'extraction_confidence': row.get('confidence', 0),
                'symptoms': [],
                'physical_findings': [],
                'lab_results': [],
                'diagnostic_hints': [],
                'diagnostic_tests': {},
                'clinical_hints': {}
            }
            
            # Parse symptoms with proper English/Portuguese separation
            if pd.notna(row.get('chief_complaints_english')):
                chief_en = str(row['chief_complaints_english']).split(';')
                chief_pt = str(row.get('chief_complaints_portuguese', '')).split(';')
                for i, symptom in enumerate(chief_en):
                    if symptom.strip():
                        condition['symptoms'].append({
                            'english': symptom.strip(),
                            'portuguese': chief_pt[i].strip() if i < len(chief_pt) else symptom.strip(),
                            'is_chief': True
                        })

            if pd.notna(row.get('other_symptoms_english')):
                other_en = str(row['other_symptoms_english']).split(';')
                other_pt = str(row.get('other_symptoms_portuguese', '')).split(';')
                for i, symptom in enumerate(other_en):
                    if symptom.strip():
                        condition['symptoms'].append({
                            'english': symptom.strip(),
                            'portuguese': other_pt[i].strip() if i < len(other_pt) else symptom.strip(),
                            'is_chief': False
                        })
            
            # Parse other fields with proper English/Portuguese separation
            for field_base, list_key in [
                ('physical_findings', 'physical_findings'),
                ('lab_results', 'lab_results'),
                ('diagnostic_hints', 'diagnostic_hints')
            ]:
                field_en = field_base + '_english'
                field_pt = field_base + '_portuguese'

                if pd.notna(row.get(field_en)):
                    items_en = str(row[field_en]).split(';')
                    items_pt = str(row.get(field_pt, '')).split(';')
                    for i, item in enumerate(items_en):
                        if item.strip():
                            condition[list_key].append({
                                'english': item.strip(),
                                'portuguese': items_pt[i].strip() if i < len(items_pt) else item.strip()
                            })

            # Parse diagnostic tests
            diagnostic_tests = {}
            test_types = ['temperature', 'xray', 'blood_test', 'ecg', 'ultrasound', 'mri', 'ct_scan', 'other_tests']
            for test_type in test_types:
                test_en = row.get(f'{test_type}_english', '')
                test_pt = row.get(f'{test_type}_portuguese', '')
                if pd.notna(test_en) and str(test_en).strip():
                    diagnostic_tests[test_type] = {
                        'english': str(test_en).strip(),
                        'portuguese': str(test_pt).strip() if pd.notna(test_pt) else str(test_en).strip()
                    }
            condition['diagnostic_tests'] = diagnostic_tests

            # Parse clinical hints
            hints_en = row.get('clinical_hints_english', '')
            hints_pt = row.get('clinical_hints_portuguese', '')
            if pd.notna(hints_en) and str(hints_en).strip():
                condition['clinical_hints'] = {
                    'english': str(hints_en).strip(),
                    'portuguese': str(hints_pt).strip() if pd.notna(hints_pt) else str(hints_en).strip()
                }
            
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
            'patient_id': ['PATIENT001', 'PATIENT002'],
            'name_english': ['Enter disease name in English', 'Acute Myocardial Infarction'],
            'name_portuguese': ['Enter disease name in Portuguese', 'Infarto Agudo do Miocárdio'],
            'category_english': ['Cardiovascular/Respiratory/etc.', 'Cardiovascular'],
            'category_portuguese': ['Cardiovascular/Respiratório/etc.', 'Cardiovascular'],
            'severity_english': ['Mild/Moderate/Severe/Critical/Chronic', 'Critical'],
            'severity_portuguese': ['Leve/Moderado/Grave/Crítico/Crônico', 'Crítico'],
            'description_english': ['Brief clinical description', 'Acute coronary syndrome...'],
            'description_portuguese': ['Descrição clínica breve', 'Síndrome coronariana aguda...'],
            'chief_complaints_english': ['Main symptoms (separate with ;)', 'Crushing chest pain; Shortness of breath'],
            'queixas_principais_portuguese': ['Sintomas principais (separar com ;)', 'Dor no peito opressiva; Falta de ar'],
            'other_symptoms_english': ['Additional symptoms (separate with ;)', 'Diaphoresis; Left arm pain'],
            'outros_sintomas_portuguese': ['Sintomas adicionais (separar com ;)', 'Diaforese; Dor no braço esquerdo'],
            'physical_findings_english': ['Physical exam findings (separate with ;)', 'S4 gallop; Diaphoresis'],
            'achados_fisicos_portuguese': ['Achados do exame físico (separar com ;)', 'Galope S4; Diaforese'],
            'lab_results_english': ['Lab/imaging results (separate with ;)', 'Elevated troponin; ECG shows ST elevation'],
            'resultados_lab_portuguese': ['Resultados laboratoriais (separar com ;)', 'Troponina elevada; ECG mostra elevação ST'],
            'diagnostic_hints_english': ['Clinical pearls (separate with ;)', 'Check cardiac enzymes; Ask about risk factors'],
            'dicas_diagnosticas_portuguese': ['Dicas clínicas (separar com ;)', 'Verificar enzimas cardíacas; Perguntar sobre fatores de risco'],

            # Diagnostic tests - specific test findings
            'temperature_english': ['Temperature findings', 'Fever 38.5°C'],
            'temperatura_portuguese': ['Achados de temperatura', 'Febre 38,5°C'],
            'xray_english': ['X-ray findings only', 'Pulmonary edema'],
            'raio_x_portuguese': ['Achados de raio-X apenas', 'Edema pulmonar'],
            'blood_test_english': ['Blood test results only', 'Troponin elevated'],
            'exame_sangue_portuguese': ['Resultados do exame de sangue apenas', 'Troponina elevada'],
            'ecg_english': ['ECG findings only', 'ST elevation in leads II, III, aVF'],
            'ecg_portuguese': ['Achados do ECG apenas', 'Elevação ST em derivações II, III, aVF'],
            'ultrasound_english': ['Ultrasound findings only', 'Reduced ejection fraction'],
            'ultrassom_portuguese': ['Achados do ultrassom apenas', 'Fração de ejeção reduzida'],
            'mri_english': ['MRI findings only', 'Myocardial scarring'],
            'ressonancia_portuguese': ['Achados da ressonância apenas', 'Cicatriz miocárdica'],
            'ct_scan_english': ['CT scan findings only', 'No pulmonary embolism'],
            'tomografia_portuguese': ['Achados da tomografia apenas', 'Sem embolia pulmonar'],
            'urinalysis_english': ['Urine test findings only', 'Protein in urine'],
            'exame_urina_portuguese': ['Achados do exame de urina apenas', 'Proteína na urina'],
            'biopsy_english': ['Biopsy results only', 'Malignant cells present'],
            'biopsia_portuguese': ['Resultados da biópsia apenas', 'Células malignas presentes'],
            'other_tests_english': ['Other test results', 'Stress test positive'],
            'outros_exames_portuguese': ['Outros exames', 'Teste de estresse positivo'],

            # Clinical hints for when patient needs help
            'clinical_hints_english': ['Hints to give patient when stuck', 'Think about cardiac causes of chest pain'],
            'dicas_clinicas_portuguese': ['Dicas para dar ao paciente quando precisar', 'Pense em causas cardíacas de dor no peito']
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
