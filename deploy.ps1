# deploy.ps1 — Manual deploy to GitHub Pages
# Usage: .\deploy.ps1 -Repo USERNAME/amarakosha
# Example: .\deploy.ps1 -Repo sramaka/amarakosha

param(
    [Parameter(Mandatory=$true)]
    [string]$Repo   # e.g. "sramaka/amarakosha"
)

$ErrorActionPreference = "Stop"

$repoName = ($Repo -split "/")[1]
$remote   = "https://github.com/$Repo.git"
$baseHref = "/$repoName/"

Write-Host ""
Write-Host "Building Flutter web (base-href: $baseHref) ..."
flutter build web --release --base-href $baseHref
if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

Write-Host ""
Write-Host "Deploying build/web to $remote [gh-pages branch] ..."

Push-Location build/web

    # Initialise a throwaway repo containing only the built artefacts
    git init -q
    git checkout -b gh-pages
    git add -A
    git commit -q -m "Deploy $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

    # Force-push to the real remote's gh-pages branch
    git push -f $remote HEAD:gh-pages

Pop-Location

# Remove the throwaway .git so it doesn't interfere with the main repo
Remove-Item -Recurse -Force build/web/.git

Write-Host ""
Write-Host "Done.  Live at: https://$($Repo.Split('/')[0]).github.io/$repoName/"
