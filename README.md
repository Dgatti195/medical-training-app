# Medical Training App

AI-powered medical education app for medical students to practice diagnostic skills through patient interviews.

## 🏥 Features

- **AI Patient Interviews**: Students interview AI patients powered by Claude
- **Test Ordering**: Order medical tests and get realistic results
- **Bilingual Support**: Full English/Portuguese localization
- **Progress Tracking**: Comprehensive analytics on performance
- **PDF Extraction**: Extract medical conditions from textbooks using AI

## 📱 iOS App

Built with SwiftUI and Core Data, featuring:
- Patient simulation with AI responses
- Medical database with 5 conditions
- User profile and progress tracking
- Hints and diagnostic guidance system

## 🐍 Python Extraction Pipeline

AI-powered pipeline to extract medical data from PDF textbooks:
- `pdf_extractor.py` - Extract conditions using Claude AI
- `manual_curator.py` - Review and edit extracted data
- `database_populator.py` - Populate SQLite database

## 🚀 Setup

### iOS App
1. Open `ios-app/Med.IA4.0_CLAUDE.xcodeproj` in Xcode
2. Add your Claude API key to the code
3. Build and run

### Python Pipeline
1. Install dependencies: `pip install -r requirements.txt`
2. Add your API key to `config/.env`
3. Run extraction: `python python-extraction/pdf_extractor.py`

## 📊 Database Schema

- **Diseases** - Medical conditions with categories
- **Symptoms** - Chief complaints and additional symptoms  
- **Physical Findings** - Exam findings
- **Lab Results** - Laboratory and imaging results
- **Demographics** - Patient demographics

## 🤝 Contributing

This is a learning project for medical education. Feel free to suggest improvements!
