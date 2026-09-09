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

Windows 10/11에서 프로젝트 루트의 `github-bootstrap.cmd`를 실행합니다.

상단의 다음 값만 필요에 따라 수정합니다.

```bat
set "REPO_OWNER="
set "REPO_NAME=timetrail"
set "REPO_VISIBILITY=public"
set "REPO_DESCRIPTION=Interactive historical map for exploring places, people and events through time."
set "REPO_TOPICS=history,maplibre,javascript,openstreetmap,github-pages,education,timeline"
```

`REPO_OWNER`를 비워두면 현재 `gh` 로그인 계정을 자동 사용합니다. 조직 Repository를 만들 경우 조직명을 입력합니다.

Bootstrap 처리 순서:

1. Git 확인
2. 프로젝트에 필요한 경우 Node.js / npm 확인
3. GitHub CLI `gh` 확인
4. `gh auth status` 확인 및 필요 시 `gh auth login`
5. Git `user.name` / `user.email` 확인 및 누락 시 입력
6. 로컬 Git 초기화 및 `main` branch 정규화
7. `npm ci` → check/test/build
8. GitHub Repository 존재 여부 확인 및 없으면 생성
9. `origin` 연결/검증
10. 변경 파일 commit
11. `main` push
12. Description / Homepage / Topics / default branch 설정
13. GitHub Pages를 Actions 방식으로 생성 또는 업데이트
14. 현재 commit SHA의 deployment workflow 추적
15. `gh run watch --exit-status`로 실제 배포 성공 확인
16. 성공 후 `v1.0.0` annotated tag 생성/push
17. 실제 Pages URL 출력

이미 Repository, Git remote, commit, Pages 설정, tag가 존재하면 가능한 한 재사용하므로 반복 실행에 안전한 형태로 구성했습니다. 기존 원격 history와 로컬 history가 충돌하는 경우에는 강제 push를 하지 않고 안전한 복구 명령을 표시합니다.

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
