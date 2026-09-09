@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

rem ============================================================
rem TimeTrail GitHub bootstrap configuration
rem Edit only these values when needed.
rem ============================================================
set "REPO_OWNER="
set "REPO_NAME=timetrail"
set "REPO_VISIBILITY=public"
set "REPO_DESCRIPTION=Interactive historical map for exploring places, people and events through time."
set "REPO_TOPICS=history,maplibre,javascript,openstreetmap,github-pages,education,timeline"
set "DEFAULT_BRANCH=main"
set "INITIAL_TAG=v1.0.0"
set "INITIAL_COMMIT=feat: launch TimeTrail interactive history map"
set "WORKFLOW_FILE=deploy.yml"
set "API_VERSION=2026-03-10"

set "NEEDS_NODE=0"
set "DEPLOY_MODE=branch"
if exist "package.json" set "NEEDS_NODE=1"
if exist ".github\workflows\%WORKFLOW_FILE%" set "DEPLOY_MODE=workflow"

call :check_cmd git "Git" "winget install --id Git.Git -e"
if errorlevel 1 exit /b 1
for /f "delims=" %%v in ('git --version') do echo [OK] %%v

if "%NEEDS_NODE%"=="1" (
  call :check_cmd node "Node.js" "winget install --id OpenJS.NodeJS.LTS -e"
  if errorlevel 1 exit /b 1
  call :check_cmd npm "npm" "Node.js LTS를 다시 설치하세요."
  if errorlevel 1 exit /b 1
  for /f "delims=" %%v in ('node --version') do echo [OK] Node %%v
  for /f "delims=" %%v in ('npm --version') do echo [OK] npm %%v
) else (
  echo [OK] Node.js가 필요 없는 정적 프로젝트로 감지했습니다.
)

call :check_cmd gh "GitHub CLI" "winget install --id GitHub.cli -e"
if errorlevel 1 exit /b 1
for /f "delims=" %%v in ('gh --version ^| findstr /B /C:"gh version"') do echo [OK] %%v

echo [CHECK] GitHub authentication
gh auth status >nul 2>&1
if errorlevel 1 (
  echo [WARN] GitHub 로그인이 필요합니다. gh auth login을 시작합니다.
  gh auth login
  if errorlevel 1 (
    echo [ERROR] GitHub 로그인에 실패했습니다.
    echo [RECOVERY] gh auth login
    exit /b 1
  )
)
echo [OK] GitHub 로그인 확인

if not defined REPO_OWNER (
  for /f "delims=" %%u in ('gh api user --jq .login') do set "REPO_OWNER=%%u"
)
if not defined REPO_OWNER (
  echo [ERROR] Repository owner를 확인하지 못했습니다.
  echo [RECOVERY] 이 파일 상단 REPO_OWNER에 GitHub 사용자명 또는 조직명을 입력하세요.
  exit /b 1
)
set "FULL_REPO=!REPO_OWNER!/%REPO_NAME%"
set "REPO_URL=https://github.com/!FULL_REPO!.git"
set "PAGES_URL=https://!REPO_OWNER!.github.io/%REPO_NAME%/"
echo [OK] 대상 Repository: !FULL_REPO!
echo [OK] 배포 방식: %DEPLOY_MODE%

if not exist ".git" (
  echo [CHECK] Git repository 초기화
  git init
  if errorlevel 1 (
    echo [ERROR] git init 실패
    exit /b 1
  )
  echo [OK] Git repository 초기화
) else (
  echo [OK] 기존 Git repository 사용
)

git branch -M "%DEFAULT_BRANCH%" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] 기본 branch를 %DEFAULT_BRANCH%로 설정하지 못했습니다.
  echo [RECOVERY] git branch -M %DEFAULT_BRANCH%
  exit /b 1
)

echo [CHECK] Git 사용자 정보
for /f "delims=" %%u in ('git config user.name 2^>nul') do set "GIT_NAME=%%u"
if not defined GIT_NAME for /f "delims=" %%u in ('git config --global user.name 2^>nul') do set "GIT_NAME=%%u"
if not defined GIT_NAME (
  set /p "GIT_NAME=Git user.name을 입력하세요: "
  if not defined GIT_NAME (
    echo [ERROR] Git user.name이 필요합니다.
    exit /b 1
  )
  git config user.name "!GIT_NAME!"
)
for /f "delims=" %%u in ('git config user.email 2^>nul') do set "GIT_EMAIL=%%u"
if not defined GIT_EMAIL for /f "delims=" %%u in ('git config --global user.email 2^>nul') do set "GIT_EMAIL=%%u"
if not defined GIT_EMAIL (
  set /p "GIT_EMAIL=Git user.email을 입력하세요: "
  if not defined GIT_EMAIL (
    echo [ERROR] Git user.email이 필요합니다.
    exit /b 1
  )
  git config user.email "!GIT_EMAIL!"
)
echo [OK] Git 사용자: !GIT_NAME! ^<!GIT_EMAIL!^>

if "%NEEDS_NODE%"=="1" (
  echo [CHECK] Repository URL 기반 메타데이터 구성
  if exist "scripts\configure-repo.mjs" (
    node scripts\configure-repo.mjs "!REPO_OWNER!" "%REPO_NAME%"
    if errorlevel 1 (
      echo [ERROR] canonical/OG URL 구성 실패
      echo [RECOVERY] node scripts\configure-repo.mjs !REPO_OWNER! %REPO_NAME%
      exit /b 1
    )
  )

  echo [CHECK] Dependencies / check / test / build
  if exist "package-lock.json" (
    call npm ci --no-audit --no-fund
  ) else (
    call npm install --no-audit --no-fund
  )
  if errorlevel 1 goto :build_error
  call npm run check --if-present
  if errorlevel 1 goto :build_error
  call npm run test --if-present
  if errorlevel 1 goto :build_error
  call npm run build
  if errorlevel 1 goto :build_error
  echo [OK] Local build/test 성공
)

echo [CHECK] GitHub Repository 존재 여부
gh repo view "!FULL_REPO!" >nul 2>&1
if errorlevel 1 (
  echo [CHECK] 새 Repository 생성: !FULL_REPO!
  git remote get-url origin >nul 2>&1
  if errorlevel 1 (
    gh repo create "!FULL_REPO!" --%REPO_VISIBILITY% --description "%REPO_DESCRIPTION%" --source . --remote origin
  ) else (
    gh repo create "!FULL_REPO!" --%REPO_VISIBILITY% --description "%REPO_DESCRIPTION%" --source .
  )
  if errorlevel 1 (
    echo [ERROR] GitHub Repository 생성 실패
    echo [RECOVERY] gh repo create !FULL_REPO! --%REPO_VISIBILITY% --source .
    exit /b 1
  )
  echo [OK] Repository 생성 완료
) else (
  echo [OK] 기존 Repository 사용: !FULL_REPO!
)

for /f "delims=" %%r in ('git remote get-url origin 2^>nul') do set "ORIGIN_URL=%%r"
if not defined ORIGIN_URL (
  git remote add origin "!REPO_URL!"
  echo [OK] origin 연결: !REPO_URL!
) else (
  echo !ORIGIN_URL! | findstr /I /C:"github.com/!REPO_OWNER!/%REPO_NAME%" >nul
  if errorlevel 1 (
    echo [WARN] 기존 origin이 대상 Repository와 다릅니다: !ORIGIN_URL!
    git remote set-url origin "!REPO_URL!"
    if errorlevel 1 (
      echo [ERROR] origin 수정 실패
      echo [RECOVERY] git remote set-url origin !REPO_URL!
      exit /b 1
    )
    echo [OK] origin을 !REPO_URL! 로 수정했습니다.
  ) else (
    echo [OK] origin 확인: !ORIGIN_URL!
  )
)

echo [CHECK] GitHub Pages pre-enable
if /I "%DEPLOY_MODE%"=="workflow" (
  gh api -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" >nul 2>&1
  if errorlevel 1 (
    gh api --method POST -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" -f build_type=workflow >nul 2>&1
    if errorlevel 1 (
      echo [WARN] Push 전에 Pages 활성화를 완료하지 못했습니다. Push 후 다시 시도합니다.
      set "PAGES_RETRY=1"
    ) else (
      echo [OK] Pages 생성: GitHub Actions
    )
  ) else (
    gh api --method PUT -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" -f build_type=workflow >nul 2>&1
    if errorlevel 1 (
      echo [WARN] Pages workflow 설정 업데이트를 Push 후 재시도합니다.
      set "PAGES_RETRY=1"
    ) else (
      echo [OK] Pages 업데이트: GitHub Actions
    )
  )
)

echo [CHECK] Commit
git add -A
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "%INITIAL_COMMIT%"
  if errorlevel 1 (
    echo [ERROR] Commit 실패
    echo [RECOVERY] git status ^& git commit -m "%INITIAL_COMMIT%"
    exit /b 1
  )
  echo [OK] Commit 생성
) else (
  echo [OK] Commit할 새 변경사항 없음
)

echo [CHECK] Push %DEFAULT_BRANCH%
git push -u origin "%DEFAULT_BRANCH%"
if errorlevel 1 (
  echo [ERROR] Push 실패
  echo [RECOVERY] 원격에 기존 커밋이 있다면: git pull --rebase origin %DEFAULT_BRANCH%
  echo [RECOVERY] 그 다음: git push -u origin %DEFAULT_BRANCH%
  exit /b 1
)
echo [OK] Push 완료

for /f "delims=" %%s in ('git rev-parse HEAD') do set "HEAD_SHA=%%s"

echo [CHECK] Repository metadata
gh repo edit "!FULL_REPO!" --description "%REPO_DESCRIPTION%" --homepage "!PAGES_URL!" --default-branch "%DEFAULT_BRANCH%" >nul 2>&1
if errorlevel 1 echo [WARN] Description/Homepage/default branch 일부 설정에 실패했습니다.
for %%t in (%REPO_TOPICS:,= %) do gh repo edit "!FULL_REPO!" --add-topic "%%t" >nul 2>&1
echo [OK] Repository metadata 설정 시도 완료

echo [CHECK] GitHub Pages 설정 확인
if /I "%DEPLOY_MODE%"=="workflow" (
  if defined PAGES_RETRY (
    gh api -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" >nul 2>&1
    if errorlevel 1 (
      gh api --method POST -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" -f build_type=workflow >nul 2>&1
    ) else (
      gh api --method PUT -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" -f build_type=workflow >nul 2>&1
    )
    if errorlevel 1 goto :pages_error
    echo [OK] Pages workflow 설정 재시도 성공
  ) else (
    echo [OK] Pages workflow 설정 확인
  )
) else (
  gh api -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" >nul 2>&1
  if errorlevel 1 (
    gh api --method POST -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" -f build_type=legacy -F "source[branch]=%DEFAULT_BRANCH%" -F "source[path]=/" >nul 2>&1
    if errorlevel 1 goto :pages_error
    echo [OK] Pages 생성: %DEFAULT_BRANCH% /
  ) else (
    gh api --method PUT -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" -f build_type=legacy -F "source[branch]=%DEFAULT_BRANCH%" -F "source[path]=/" >nul 2>&1
    if errorlevel 1 goto :pages_error
    echo [OK] Pages 업데이트: %DEFAULT_BRANCH% /
  )
)

if /I "%DEPLOY_MODE%"=="workflow" (
  echo [CHECK] GitHub Actions deployment run 탐색
  set "RUN_ID="
  for /L %%i in (1,1,15) do (
    if not defined RUN_ID (
      for /f "delims=" %%r in ('gh run list --repo "!FULL_REPO!" --workflow "%WORKFLOW_FILE%" --commit "!HEAD_SHA!" --limit 1 --json databaseId --jq ".[0].databaseId // empty" 2^>nul') do set "RUN_ID=%%r"
      if not defined RUN_ID timeout /t 4 /nobreak >nul
    )
  )
  if not defined RUN_ID (
    echo [WARN] Push로 시작된 workflow run을 찾지 못했습니다. workflow_dispatch를 시도합니다.
    gh workflow run "%WORKFLOW_FILE%" --repo "!FULL_REPO!" --ref "%DEFAULT_BRANCH%" >nul 2>&1
    if errorlevel 1 (
      echo [ERROR] Workflow 실행을 시작하지 못했습니다.
      echo [RECOVERY] gh workflow run %WORKFLOW_FILE% --repo !FULL_REPO! --ref %DEFAULT_BRANCH%
      exit /b 1
    )
    for /L %%i in (1,1,15) do (
      if not defined RUN_ID (
        for /f "delims=" %%r in ('gh run list --repo "!FULL_REPO!" --workflow "%WORKFLOW_FILE%" --branch "%DEFAULT_BRANCH%" --limit 1 --json databaseId --jq ".[0].databaseId // empty" 2^>nul') do set "RUN_ID=%%r"
        if not defined RUN_ID timeout /t 4 /nobreak >nul
      )
    )
  )
  if not defined RUN_ID (
    echo [ERROR] Workflow run ID를 확인하지 못했습니다.
    echo [RECOVERY] gh run list --repo !FULL_REPO! --workflow %WORKFLOW_FILE%
    exit /b 1
  )
  echo [CHECK] Workflow run !RUN_ID! 완료 대기
  gh run watch !RUN_ID! --repo "!FULL_REPO!" --exit-status
  if errorlevel 1 (
    echo [WARN] 첫 배포 run이 실패했습니다. Pages 설정 완료 후 workflow_dispatch로 한 번 재시도합니다.
    echo [WARN] 실패 로그: gh run view !RUN_ID! --repo !FULL_REPO! --log-failed
    set "RETRY_RUN_ID="
    gh workflow run "%WORKFLOW_FILE%" --repo "!FULL_REPO!" --ref "%DEFAULT_BRANCH%" >nul 2>&1
    if errorlevel 1 (
      echo [ERROR] 배포 재시도 시작 실패
      echo [RECOVERY] gh workflow run %WORKFLOW_FILE% --repo !FULL_REPO! --ref %DEFAULT_BRANCH%
      exit /b 1
    )
    for /L %%i in (1,1,15) do (
      if not defined RETRY_RUN_ID (
        for /f "delims=" %%r in ('gh run list --repo "!FULL_REPO!" --workflow "%WORKFLOW_FILE%" --event workflow_dispatch --branch "%DEFAULT_BRANCH%" --limit 1 --json databaseId --jq ".[0].databaseId // empty" 2^>nul') do set "RETRY_RUN_ID=%%r"
        if not defined RETRY_RUN_ID timeout /t 4 /nobreak >nul
      )
    )
    if not defined RETRY_RUN_ID (
      echo [ERROR] 재시도 workflow run을 찾지 못했습니다.
      echo [RECOVERY] gh run list --repo !FULL_REPO! --workflow %WORKFLOW_FILE%
      exit /b 1
    )
    gh run watch !RETRY_RUN_ID! --repo "!FULL_REPO!" --exit-status
    if errorlevel 1 (
      echo [ERROR] GitHub Actions 배포 재시도도 실패했습니다.
      echo [RECOVERY] gh run view !RETRY_RUN_ID! --repo !FULL_REPO! --log-failed
      exit /b 1
    )
  )
  echo [OK] GitHub Actions 배포 성공
) else (
  echo [CHECK] Branch Pages 배포 상태
  timeout /t 5 /nobreak >nul
  gh api -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" >nul 2>&1
  if errorlevel 1 (
    echo [ERROR] GitHub Pages 상태 확인 실패
    echo [RECOVERY] gh api repos/!FULL_REPO!/pages
    exit /b 1
  )
  echo [OK] GitHub Pages 활성화 확인
)

for /f "delims=" %%p in ('gh api -H "X-GitHub-Api-Version: %API_VERSION%" "repos/!FULL_REPO!/pages" --jq .html_url 2^>nul') do set "ACTUAL_PAGES_URL=%%p"
if not defined ACTUAL_PAGES_URL set "ACTUAL_PAGES_URL=!PAGES_URL!"

echo [CHECK] Initial tag %INITIAL_TAG%
git fetch --tags origin >nul 2>&1
git rev-parse "%INITIAL_TAG%" >nul 2>&1
if errorlevel 1 (
  git tag -a "%INITIAL_TAG%" -m "TimeTrail %INITIAL_TAG%"
  if errorlevel 1 (
    echo [ERROR] Tag 생성 실패
    exit /b 1
  )
  git push origin "%INITIAL_TAG%"
  if errorlevel 1 (
    echo [ERROR] Tag push 실패
    echo [RECOVERY] git push origin %INITIAL_TAG%
    exit /b 1
  )
  echo [OK] %INITIAL_TAG% 생성 및 push
) else (
  echo [OK] %INITIAL_TAG%가 이미 존재합니다.
)

echo.
echo ============================================================
echo [OK] TimeTrail bootstrap 완료
echo [OK] Repository: https://github.com/!FULL_REPO!
echo [OK] Pages: !ACTUAL_PAGES_URL!
echo ============================================================
exit /b 0

:check_cmd
where %~1 >nul 2>&1
if errorlevel 1 (
  echo [ERROR] %~2를 찾을 수 없습니다.
  echo [RECOVERY] %~3
  exit /b 1
)
echo [OK] %~2 확인
exit /b 0

:build_error
echo [ERROR] Dependency 설치 또는 check/test/build가 실패했습니다.
echo [RECOVERY] npm ci --no-audit --no-fund ^&^& npm run check --if-present ^&^& npm run test --if-present ^&^& npm run build
exit /b 1

:pages_error
echo [ERROR] GitHub Pages 설정 실패
if /I "%DEPLOY_MODE%"=="workflow" (
  echo [RECOVERY] gh api --method POST repos/!FULL_REPO!/pages -f build_type=workflow
) else (
  echo [RECOVERY] Repository Settings ^> Pages에서 %DEFAULT_BRANCH% /^(root^)를 선택하세요.
)
exit /b 1
