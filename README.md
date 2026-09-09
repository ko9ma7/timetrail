# TimeTrail

**지도를 클릭하고 시간을 움직이면 그 장소의 과거를 탐색하는 교육형 세계사 지도.**

TimeTrail은 역사 사실을 LLM이 임의로 만들어내는 대신, **내장 교육 데이터 + 세계사 Backbone + Wikidata 구조화 데이터 + Wikipedia/Wikimedia 원문**을 결합합니다. GitHub Pages에서 정적으로 동작하며 별도 DB가 필요하지 않습니다.

### v1.2.2 bootstrap consistency fix

The Windows bootstrap no longer hard-codes a second build marker in `github-bootstrap.cmd`. The PowerShell deployment engine reads the release version from `package.json` and the build marker from `index.html`, then verifies that `app.js` uses the same cache/data version. `npm run check` also runs `scripts/verify-release.mjs`, so mixed files from different releases fail during local/CI checks instead of during deployment.

## Current data scale (v1.2.2)

- 상세 교육 큐레이션: **80개 사건**
- 내장 세계사 Backbone: **211개 사건/기준점**
- 기본 내장 합계: **291개 기록**
- 교육 Story Pack: **30개 / 약 160개 학습 지점**
- Time Duel 도시: **24개**
- 시간 범위: **기원전 3500년 ~ 2026년**
- Wikidata 자동 인덱스: **최대 45,000개**로 설정 가능

> 자동 인덱스는 repository에 처음부터 45,000건을 억지로 넣는 것이 아니라 `npm run data:refresh` 또는 GitHub Actions가 Wikidata에서 날짜·좌표가 있는 항목을 수집해 생성합니다. 따라서 원문 QID와 좌표 근거를 유지하면서 계속 확장할 수 있습니다.

## Preview

첫 화면에서 세계지도, 시간 슬라이더, 사건 목록과 교육 카드가 보입니다. 사건을 선택하면 핵심 요약, 중요성, 학습 포인트, 관련 인물/장소, Wikipedia 대표 이미지와 개요, 추가 읽기 링크를 확인할 수 있습니다.

## Features

### Explore

- MapLibre GL + OpenStreetMap 세계지도
- 기원전 3500년~2026년 Time Slider
- 지도 클릭 → 선택 시기와 위치를 함께 고려해 가까운 역사 기록 탐색
- 장소·국가·인물·사건 검색
- 대규모 데이터에서도 현재 연도 주변 레코드만 추려 지도 마커를 렌더링

### Educational history cards

- 무슨 일이 있었는가
- 왜 중요한가
- 핵심 학습 포인트
- 관련 인물·장소
- 자료 계층 / 좌표 정확도 / 검토 상태
- Wikipedia 대표 이미지·개요 자동 조회
- 한국어/영문 Wikipedia, Wikidata, 나무위키 검색, Wikimedia Commons 연결

### Story Packs

30개의 교육 경로가 포함됩니다. 예:

- 마르코 폴로의 동방 여행
- 이순신의 1592년
- 실크로드
- 알렉산드로스 동방 원정
- 불교 전파
- 몽골 제국
- 흑사병
- 바스쿠 다 가마
- 마젤란-엘카노 세계일주
- 종교개혁
- 대서양 노예무역과 저항
- 미국혁명
- 라틴아메리카 독립
- 산업혁명
- 메이지 일본
- 인도 독립운동
- 한국 독립운동
- 미국 민권운동
- 베를린 냉전
- 사하라 횡단 교역
- 오스만 제국
- 아즈텍/잉카 정복
- 아시아 탈식민화

### Time Duel

서울 vs 런던처럼 같은 시기에 두 도시 주변의 가장 가까운 역사 기록을 비교합니다.

### Local preferences

즐겨찾기와 다크/라이트 테마를 LocalStorage에 저장합니다.

## Data architecture

```text
data/history-events.json
  = 깊이 있는 교육 큐레이션

        +

data/history-backbone.json
  = 기원전~현대 세계사 기본 골격

        +

data/history-events-index.json
  = Wikidata 자동 대규모 인덱스 (0~45,000+)

        +

data/history-imported.json
  = 사용자가 CSV/JSON으로 추가한 자료

        ↓

TimeTrail 지도 / 검색 / Time Duel / 교육 카드
```

### Data provenance

모든 레코드에는 가능한 범위에서 다음 메타데이터를 둡니다.

```text
sourceTier
coordinatePrecision
reviewStatus
wikidataId
sourceUrl
wikipediaUrl
```

좌표가 정확한 유적 지점인지, 도시 중심점인지, 넓은 지역의 근사점인지 구분할 수 있습니다.

## How to add more historical data

상세한 한국어 설명은 **[docs/DATA-GUIDE-KO.md](docs/DATA-GUIDE-KO.md)** 를 참고하세요.

### 1. 교육용 핵심 사건 직접 추가

`data/history-events.json`에 레코드를 추가합니다.

### 2. CSV로 대량 추가

`data/history-template.csv`를 복사하여 작성한 뒤:

```bash
npm run data:import -- ./data/my-history.csv ./data/history-imported.json
```

### 3. Wikidata 자동 수집

```bash
npm run data:refresh
```

수집량과 유형은 `data/harvest-config.json`에서 수정합니다. 기본 최대치는 45,000건입니다.

### 4. GitHub Actions로 계속 갱신

`.github/workflows/refresh-history.yml`은 매주 자동 실행되며 Actions 화면에서 수동 실행도 가능합니다. 새 데이터가 생기면 bot commit으로 이력을 남기고, 같은 `Refresh historical data index` workflow가 새 `dist/`를 GitHub Pages에 직접 재배포합니다.

## Coordinate methodology

역사 사건은 모두 정확한 한 점이 아닙니다. `coordinatePrecision`을 함께 기록합니다.

| 값 | 의미 |
|---|---|
| `site` | 실제 유적/전투지 등 비교적 정확한 좌표 |
| `city` | 도시 전체 사건, 도시 대표 좌표 |
| `city-or-region` | 도시/지역 중심점으로 근사 |
| `region` | 넓은 전쟁·교역·대유행 지역 대표점 |
| `approximate` | 고대 지명 등 추정 위치 |
| `unknown` | 자동 수집 후 미분류 |

권장 좌표 출처 순서는 **Wikidata P625 → Wikipedia 좌표 → OpenStreetMap/Nominatim → GeoNames 교차 확인**입니다.

## Tech Stack

- HTML5 / CSS3 / JavaScript ES Modules
- MapLibre GL JS
- OpenStreetMap raster tiles
- Wikipedia / MediaWiki API
- Wikidata Query Service
- Static JSON
- LocalStorage
- GitHub Actions
- GitHub Pages

## Project Structure

```text
/
├─ data/
│  ├─ history-events.json          # 상세 큐레이션
│  ├─ history-backbone.json        # 세계사 백본
│  ├─ history-events-index.json    # 자동 대규모 인덱스
│  ├─ history-imported.json        # 사용자 가져오기
│  ├─ history-schema.json          # 데이터 스키마
│  ├─ harvest-config.json          # Wikidata 수집 설정
│  ├─ history-template.csv         # CSV 입력 템플릿
│  ├─ story-packs.json
│  └─ cities.json
├─ docs/
│  ├─ DATA-GUIDE-KO.md
│  └─ PROJECT-SUMMARY-KO.md
├─ scripts/
│  ├─ build.mjs
│  ├─ configure-repo.mjs
│  ├─ refresh-history.mjs
│  ├─ import-history-csv.mjs
│  ├─ data-stats.mjs
│  └─ github-bootstrap.ps1
├─ .github/workflows/
│  ├─ deploy.yml
│  └─ refresh-history.yml
├─ github-bootstrap.cmd
├─ app.js
├─ styles.css
├─ index.html
└─ README.md
```

## Local Development

의존 패키지가 거의 없는 정적 프로젝트입니다.

```bash
npm ci
npm run check
npm run dev
```

브라우저에서 `http://localhost:5173/`를 엽니다.

## Build

```bash
npm ci
npm run check
npm run build
```

결과는 `dist/`에 생성됩니다.

데이터 현황 확인:

```bash
npm run data:stats
```

## GitHub Pages Deployment

### Windows one-click

ZIP을 **완전히 압축 해제한 폴더**에서:

```text
github-bootstrap.cmd
```

을 실행합니다.

스크립트는 다음을 처리합니다.

1. 프로젝트/데이터 검사
2. Git, Node, npm, `gh` 확인
3. GitHub 로그인 확인
4. 기존 GitHub repository/`origin` 재사용 또는 연결
5. build/check
6. commit/push
7. Pages Actions 실행 확인
8. 실제 배포 URL 확인
9. 로그 보존

실패하면 `github-bootstrap.log`를 확인합니다.

### Manual deployment

1. GitHub repository에 push
2. **Settings → Pages → Source: GitHub Actions**
3. `.github/workflows/deploy.yml` 실행

## Automatic data refresh

GitHub에서:

```text
Actions
→ Refresh historical data index
→ Run workflow
```

`max_records`를 조정할 수 있습니다. 기본값은 45,000입니다.

WDQS가 일시적으로 429/5xx를 반환하면 스크립트는 지수 백오프로 재시도하고, 특정 유형이 계속 실패하면 해당 유형을 건너뛰고 나머지를 보존합니다.

## Web metadata / branding

- favicon SVG/ICO/PNG
- Apple Touch Icon
- 192/512 app icons
- Open Graph image
- GitHub Repository Social Preview
- Web Manifest
- robots.txt / sitemap.xml
- 404 page

## Project history / current design rationale

지금까지의 전체 기획·기능·데이터 구조·Windows 배포 문제 수정 내용은 **[docs/PROJECT-SUMMARY-KO.md](docs/PROJECT-SUMMARY-KO.md)** 에 정리되어 있습니다.

## Security

GitHub Pages는 공개 프론트엔드입니다. API token, GitHub PAT, password, private key를 저장소나 JavaScript에 넣지 마세요. 현재 Wikidata/Wikipedia 수집은 공개 API만 사용하므로 별도 secret이 필요하지 않습니다.

## License

프로젝트 코드는 MIT License입니다. 외부 Wikipedia/Wikimedia/Wikidata 콘텐츠와 이미지는 각 원 출처의 라이선스를 따릅니다. Wikidata 구조화 데이터는 원 출처 정책을 확인하고 사용하세요.
