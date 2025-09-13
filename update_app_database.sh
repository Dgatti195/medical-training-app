#!/bin/bash

echo "🔄 Updating iOS app with latest medical database..."

# Step 1: Run the Python database populator
echo "📊 Populating database with extracted conditions..."
cd python-extraction
python3 database_populator.py

# Step 2: Copy the populated database to the iOS app bundle
echo "📱 Copying database to iOS app bundle..."
cd ..
cp output/databases/medical_database.sqlite ios-app/Med.IA4.0_CLAUDE/Med.IA4.0_CLAUDE/medical_conditions.sqlite

# Step 3: Verify the copy was successful
RECORD_COUNT=$(sqlite3 ios-app/Med.IA4.0_CLAUDE/Med.IA4.0_CLAUDE/medical_conditions.sqlite "SELECT COUNT(*) FROM diseases;")
echo "✅ Database copied successfully with $RECORD_COUNT medical conditions"

echo ""
echo "🎉 Database update complete!"
echo "💡 Next steps:"
echo "   1. Build and run your iOS app in Xcode"
echo "   2. If you still see old data, tap 'Update Database' button in the app"
echo "   3. You should now see all $RECORD_COUNT patients/conditions!"