#!/bin/bash

echo "🔍 Checking CI/CD setup..."
echo ""

# Check if GitHub remote exists
if git remote get-url origin &> /dev/null; then
    REMOTE=$(git remote get-url origin)
    echo "✅ GitHub remote configured: $REMOTE"
else
    echo "❌ No GitHub remote found"
    echo "   Run: git remote add origin https://github.com/[username]/Cards.git"
fi

# Check if workflows exist
if [ -d ".github/workflows" ]; then
    WORKFLOW_COUNT=$(ls -1 .github/workflows/*.yml 2>/dev/null | wc -l)
    echo "✅ Workflow files exist ($WORKFLOW_COUNT files)"
else
    echo "❌ No workflow files found"
fi

# Check if Fastlane is configured
if [ -f "fastlane/Fastfile" ]; then
    echo "✅ Fastlane configured"
else
    echo "❌ Fastlane not configured"
fi

# Check if Gemfile exists
if [ -f "Gemfile" ]; then
    echo "✅ Gemfile exists"
else
    echo "❌ Gemfile not found"
fi

# Check if .gitignore exists
if [ -f ".gitignore" ]; then
    echo "✅ .gitignore configured"
else
    echo "⚠️  No .gitignore found"
fi

echo ""
echo "📋 Next steps:"
echo "1. Push code to GitHub: git push origin main"
echo "2. Configure secrets at: https://github.com/[username]/Cards/settings/secrets/actions"
echo "3. See docs/CICD_SETUP.md for detailed instructions"
echo "4. Test deployment: git tag v1.0.0 && git push origin v1.0.0"
