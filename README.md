# TimeTrail

지도를 클릭하고 연도를 움직여 장소의 과거, 역사 사건, 인물의 이동 경로를 탐험하는 인터랙티브 역사 지도입니다.

## Preview

첫 화면에서 세계 지도, 500–2026 시간 슬라이더, 역사 사건 카드가 즉시 표시됩니다. 지도 클릭, 검색, Story Pack, Time Duel, 테마 변경, 즐겨찾기가 실제로 동작합니다.

- Web OG Preview: `og-image.png` — 1200×630
- GitHub Repository Social Preview: `repository-social-preview.png` — 1280×640

## Features

- **Map exploration** — 지도 클릭 시 선택 연도와 공간적으로 가까운 역사 사건 탐색
- **Time Slider** — 500–2026 범위 탐색
- **Story Packs** — Marco Polo, 이순신의 1592년, 실크로드
- **Time Duel** — 서울/런던/베이징/파리/이스탄불의 동일 시대 비교
- **Source-first cards** — Wikipedia/Wikidata 원문 링크
- **Local persistence** — 테마/즐겨찾기 LocalStorage 저장
- **Responsive UI** — Desktop, Tablet, Mobile 대응
- **Static-first** — 핵심 데이터와 UI는 GitHub Pages에서 서버 없이 작동

## Educational dataset

현재 내장 데이터는 **80개 역사 사건 / 40개 국가·지역 / 9개 Story Pack / 24개 Time Duel 도시**를 포함합니다. 사건 카드는 단순 설명이 아니라 `왜 중요한가`, 핵심 학습 포인트, 관련 인물·장소를 제공하며, MediaWiki 공개 API를 통해 Wikipedia 대표 이미지와 요약을 보강합니다. 상세 탐구는 한국어·영어 Wikipedia, Wikidata, 나무위키 검색, Wikimedia Commons 이미지 검색으로 이어집니다.

정적 데이터는 `data/history-events.json`, `data/story-packs.json`, `data/cities.json`에서도 확인할 수 있습니다. 네트워크가 끊기거나 Wikipedia API가 실패해도 내장 교육 콘텐츠는 작동합니다.

## Tech Stack

HTML5 · CSS3 · JavaScript ES Modules · MapLibre GL JS 6.8.0 · OpenStreetMap · Node.js build script · GitHub Pages · GitHub Actions

외부 npm 런타임 라이브러리는 사용하지 않습니다. Node.js는 정적 배포 파일을 `dist/`로 묶고 배포 URL 메타데이터를 구성하는 용도로 사용합니다.

## Project Structure

```text
/
├─ .github/
│  └─ workflows/
│     └─ deploy.yml
├─ scripts/
│  ├─ build.mjs
│  └─ configure-repo.mjs
├─ index.html
├─ app.js
├─ styles.css
├─ 404.html
├─ favicon.ico
├─ favicon.svg
├─ favicon-16x16.png
├─ favicon-32x32.png
├─ apple-touch-icon.png
├─ icon-192.png
├─ icon-512.png
├─ site.webmanifest
├─ manifest.webmanifest
├─ og-image.png
├─ repository-social-preview.png
├─ robots.txt
├─ sitemap.xml
├─ .nojekyll
├─ .gitignore
├─ .gitattributes
├─ LICENSE
├─ package.json
├─ package-lock.json
├─ github-bootstrap.cmd
└─ README.md
```

## Local Development

```bash
npm ci
npm run dev
```

`npm run dev`는 Python 3의 정적 HTTP 서버를 사용합니다. Python이 없다면 VS Code Live Server 등 일반 정적 서버를 사용할 수 있습니다. ES Module 보안 정책 때문에 `file://` 직접 실행은 권장하지 않습니다.

## Check / Build

```bash
npm ci
npm run check
npm run build
```

`dist/`에 GitHub Pages 배포용 파일이 생성됩니다.

## Repository URL Configuration

OG URL, canonical URL, sitemap은 실제 GitHub 계정과 Repository 이름을 알아야 완성됩니다.

```bash
node scripts/configure-repo.mjs USERNAME REPOSITORY
npm run build
```

GitHub Actions에서는 `GITHUB_REPOSITORY_OWNER`와 `GITHUB_REPOSITORY`를 사용하여 이 작업을 자동 수행합니다. `github-bootstrap.cmd`를 이용할 때도 자동 수행됩니다.

## Windows One-click GitHub Bootstrap

**ZIP 안에서 `.cmd`를 직접 실행하지 마세요.** 먼저 Windows Explorer의 **모두 압축 풀기**로 프로젝트 전체를 새 폴더에 풀고, 그 폴더의 `github-bootstrap.cmd`를 더블클릭합니다. `RUN-ME-FIRST.txt`에도 같은 절차가 들어 있습니다.

`github-bootstrap.cmd` 상단의 다음 값만 필요에 따라 수정합니다.

```bat
set "TT_REPO_OWNER="
set "TT_REPO_NAME="
set "TT_REPO_VISIBILITY=public"
set "TT_REPO_DESCRIPTION=Interactive historical map for exploring places, people and events through time."
set "TT_REPO_TOPICS=history,maplibre,javascript,openstreetmap,github-pages,education,timeline"
set "TT_INITIAL_TAG=v1.1.4"
set "TT_EXPECTED_BUILD=2026-09-09.7"
```

`TT_REPO_OWNER`와 `TT_REPO_NAME`을 비워두면 기존 `.git`의 GitHub `origin`을 먼저 감지해 **기존 배포 저장소를 그대로 재사용**합니다. 기존 `origin`이 없을 때만 현재 `gh` 로그인 계정 + 기본 저장소명 `timetrail`을 사용합니다. 최신 폴더라면 콘솔에 `[DATA] Events: 80 / Countries-regions: 40 / Story packs: 9 / Duel cities: 24`가 표시됩니다.

> Windows 호환성: `github-bootstrap.cmd`와 실행용 PowerShell 스크립트는 의도적으로 **ASCII 문자만 사용하고 Windows CRLF 줄바꿈으로 저장**합니다. 사용자 안내 문서와 웹사이트는 계속 한국어를 사용하지만, 배포 스크립트 내부 메시지는 `cmd.exe` 문자 인코딩 파싱 오류를 피하기 위해 영문으로 표시됩니다.

Bootstrap 처리 순서:

1. ZIP 내부 단독 실행 여부 및 필수 프로젝트 파일 검사
2. 80개 사건 / 9개 Story Pack / 24개 도시 데이터 검사
3. Git / Node.js / npm / GitHub CLI 확인, 누락 시 가능한 경우 `winget` 자동 설치
4. `gh auth status` 확인 및 필요 시 브라우저 로그인
5. Git author 설정 및 로컬 Repository 초기화/`main` 정규화
6. `npm ci` → `npm run check` → `npm run build`
7. GitHub Repository 생성 또는 기존 Repository 재사용
8. `origin` 연결/교정, 변경사항 commit, `main` push
9. Description / Homepage / Topics 설정
10. GitHub Pages source를 GitHub Actions로 설정
11. **변경 commit 유무와 관계없이 새 `workflow_dispatch` 배포를 한 번 강제 실행**
12. `gh run watch --exit-status`로 실제 Actions 성공 확인
13. 원격 Pages HTML에서 build `2026-09-09.7` 확인
14. 원격 `data/history-events.json`이 80건 이상인지 확인
15. 성공 시 `v1.1.4` tag 생성/push 후 배포 사이트 자동 열기

성공/실패와 관계없이 `.cmd` 창은 마지막에 `pause` 상태로 남습니다. 모든 실행 과정은 프로젝트 루트의 `github-bootstrap.log`에도 기록됩니다. 따라서 더 이상 오류가 발생해도 창이 순식간에 사라지지 않습니다.

> **v1.1.4 Git remote 수정:** 새 ZIP 폴더에서 기존 GitHub 저장소를 재사용할 때 로컬 `origin`이 아직 없는 것이 정상입니다. v1.1.4는 `origin` 존재 여부를 먼저 검사하고 없으면 추가한 뒤, 기존 원격 `main` 이력을 working tree를 덮어쓰지 않고 연결하여 일반 fast-forward 업데이트로 배포합니다.

> **v1.1.4 데이터 검사 수정:** v1.1.2의 Windows PowerShell 5.1 검증 코드가 최상위 JSON 배열을 `@(...)`로 감싸면서 80개 사건, 9개 Story Pack, 24개 도시를 각각 `1`개로 잘못 계산했습니다. 실제 JSON 데이터나 GitHub 업로드에는 문제가 없었습니다. v1.1.4은 JSON을 먼저 파싱한 뒤 실제 배열의 `Length`를 검사하므로 `80 / 9 / 24`로 정상 표시됩니다.


### Windows에서 `내부 또는 외부 명령` 오류가 연속으로 나타나는 경우

이전 v1.1.1 패키지의 `.cmd`가 UTF-8/LF 형식으로 저장된 환경에서는 `'LITY'`, `'ation'`, `'cho'`, `'XIT_CODE'`처럼 명령의 일부만 잘려 실행되는 현상이 발생할 수 있었습니다. **v1.1.4에서는 이 문제를 수정했습니다.** 기존 `.cmd`만 덮어쓰는 대신 v1.1.4 ZIP 전체를 새 폴더에 압축 해제하여 실행하는 것을 권장합니다.

### Required local tools

- Git
- Node.js LTS / npm
- GitHub CLI (`gh`)

누락 시 `.cmd`가 `[ERROR]`와 함께 `winget` 기반 설치 예시 또는 복구 명령을 출력합니다. 인증 Token, 비밀번호, API Key는 스크립트나 Repository에 저장하지 않습니다.

## GitHub Pages Deployment

기본 배포는 `.github/workflows/deploy.yml`을 사용합니다.

```text
git push main
  ↓
GitHub Actions
  ↓
npm ci
  ↓
configure-repo.mjs
  ↓
check + build
  ↓
upload Pages artifact
  ↓
deploy-pages
```

Workflow는 다음 권한만 사용합니다.

```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```

수동 설정 시 Repository → **Settings → Pages → Source: GitHub Actions**를 선택합니다.

배포 URL 기본 형태:

```text
https://USERNAME.github.io/REPOSITORY/
```

## GitHub Repository Metadata

권장 기본값:

- Repository name: `timetrail`
- Visibility: `public`
- Description: `Interactive historical map for exploring places, people and events through time.`
- Topics: `history`, `maplibre`, `javascript`, `openstreetmap`, `github-pages`, `education`, `timeline`
- Default branch: `main`
- Initial commit: `feat: launch TimeTrail interactive history map`
- Initial tag: `v1.0.0`

GitHub Repository의 **Settings → General → Social preview**에는 `repository-social-preview.png`를 업로드하면 됩니다.

## Branding / Metadata

포함된 웹 브랜딩 파일:

- `<title>` / meta description / theme color
- canonical URL 자동 구성
- Open Graph `og:title`, `og:description`, `og:url`, `og:image`
- Twitter/X large image card
- `favicon.ico` / SVG / 16×16 / 32×32
- Apple Touch Icon 180×180
- PWA icons 192×192 / 512×512
- `site.webmanifest` 및 `manifest.webmanifest`
- `robots.txt` / `sitemap.xml`
- OG Preview 1200×630
- GitHub Social Preview 1280×640

## Configuration

역사 사건과 Story Pack은 `app.js`의 `events`, `routes`, `cities` 데이터에서 수정할 수 있습니다. 데이터 규모가 커지면 Wikidata/Wikipedia에서 검증 가능한 데이터를 빌드 시점에 가져와 정적 JSON을 생성하는 구조로 확장할 수 있습니다.

## Data / Attribution

- 지도: © OpenStreetMap contributors
- 지도 렌더러: MapLibre GL JS
- 역사 카드: 각 카드의 원문 링크에서 출처 확인

내장 역사 데이터는 서비스 UX를 완전하게 작동시키기 위한 대표 데이터셋입니다. 대규모 공개 서비스 전환 시 개별 사건의 사실관계, 출처, 라이선스를 추가 검증하십시오.

## Custom Domain

GitHub Pages Settings에서 Custom domain을 등록하고 DNS를 연결합니다. 필요하면 Repository 루트에 `CNAME` 파일을 추가할 수 있습니다. 도메인이 정상 확인된 뒤 HTTPS 강제 적용을 권장합니다.

## License

MIT License. 외부 데이터, 지도 타일 및 연결된 원문은 각 제공자의 별도 라이선스/이용 조건을 따릅니다.

## 업데이트가 화면에 안 보일 때

이 프로젝트는 `2026-09-09.7` 빌드부터 정적 JSON을 실제 앱 데이터 원본으로 사용하고, `app.js`/CSS/JSON URL에 버전을 붙여 캐시를 무효화합니다. 첫 화면 왼쪽에 `UPDATE 2026.09 · 80개 사건 · 40개 국가/지역 · 9개 Story Pack`이 보여야 최신 버전입니다.

`github-bootstrap.cmd`는 Actions 성공만 확인하지 않고 실제 GitHub Pages HTML에서 `timetrail-build=2026-09-09.7` 표식까지 확인합니다. 확인에 실패하면 성공으로 종료하지 않습니다.

기존 폴더를 쓰는 경우 새 ZIP의 파일을 기존 프로젝트에 덮어쓴 뒤 `github-bootstrap.cmd`를 다시 실행하세요. 브라우저에서는 배포 URL 뒤에 `?verify=2026-09-09.7`을 붙여 열면 CDN/브라우저 캐시 여부를 빠르게 확인할 수 있습니다.
