param(
    [string]$Owner = "OmerMachluf",
    [string]$Repo = "go-interview-prep"
)

$ErrorActionPreference = "Stop"

if (-not $env:GITHUB_TOKEN) {
    throw "Set GITHUB_TOKEN to a GitHub token that can create public repos for $Owner."
}

$headers = @{
    Authorization          = "Bearer $env:GITHUB_TOKEN"
    Accept                 = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent"           = "go-interview-prep-publisher"
}

$body = @{
    name        = $Repo
    private     = $false
    description = "Go interview prep for a C# developer, with Claude skills and cheat sheet."
} | ConvertTo-Json

$viewer = Invoke-RestMethod -Method Get -Uri "https://api.github.com/user" -Headers $headers
if ($viewer.login -ne $Owner) {
    throw "GITHUB_TOKEN is authenticated as $($viewer.login), not $Owner."
}

try {
    Invoke-RestMethod -Method Post -Uri "https://api.github.com/user/repos" -Headers $headers -Body $body -ContentType "application/json" | Out-Null
} catch {
    $status = $_.Exception.Response.StatusCode.value__
    if ($status -ne 422) {
        throw
    }
}

git remote remove origin 2>$null
git remote add origin "https://github.com/$Owner/$Repo.git"
git branch -M main
$basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("x-access-token:$env:GITHUB_TOKEN"))
git -c "http.extraHeader=Authorization: Basic $basic" push -u origin main
