param(
    [string]$sourceBranch = 'backup/GAVRA013',
    [string]$targetBranch = 'backup/GAVRA013-remote',
    [string]$tagName = 'GAVRA013-remote'
)

Write-Host "Creating remote-safe backup branch '$targetBranch' from '$sourceBranch'"

# Ensure we start from the source branch
git checkout $sourceBranch

# Create orphan target branch
git checkout --orphan $targetBranch

# Remove all files from index and working tree
git rm -rf . | Out-Null

# Restore essential project files and directories only
$allowed = @(
    '.gitattributes',
    'pubspec.yaml',
    'pubspec.lock',
    'analysis_options.yaml',
    'package.json',
    'lib',
    'android',
    'assets',
    'tools',
    'README.md',
    'firebase_options.dart',
    'supabase_client.dart'
)

foreach ($path in $allowed) {
    if (Test-Path $path) {
        git add $path 2>$null
    }
}

# Create a minimal .gitignore to ensure no large files are added
@"
# Remote-safe ignore
build/
.gradle/
apk_extracted/
*.zip
*.apk
tmp/
*.keystore
*.keystore.*
"@ | Out-File -Encoding utf8 .gitignore
git add .gitignore

# Commit only the selected files
git commit -m "remote-safe backup: snapshot without build artifacts"

# Create an annotated tag
git tag -a $tagName -m "Remote-safe snapshot of GAVRA013"

Write-Host "Created branch '$targetBranch' and tag '$tagName'"
Write-Host "Now try: git push origin $targetBranch && git push origin $tagName"
