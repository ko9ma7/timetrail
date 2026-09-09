# TimeTrail 역사 데이터 구축·좌표화·확장 가이드

## 1. 데이터는 세 층으로 관리합니다

TimeTrail은 데이터 양과 교육 품질을 동시에 확보하기 위해 한 파일에 모든 내용을 섞지 않습니다.

1. **교육 큐레이션 (`history-events.json`)**: 핵심 사건. 사실 요약, 역사적 의의, 인물, 관련 장소, 학습 포인트를 상세히 작성합니다.
2. **세계사 Backbone (`history-backbone.json`)**: 고대부터 현대까지 지도의 빈 구간을 메우는 세계사 기준점입니다. 설명은 비교적 짧지만 좌표·시대·검색어를 갖습니다.
3. **Wikidata 자동 Index (`history-events-index.json`)**: GitHub Actions가 좌표·날짜가 있는 Wikidata 항목을 대량 수집합니다. 최대 레코드 수는 `data/harvest-config.json`의 `maxRecords`로 조정합니다.

자동 인덱스는 **양을 확보하는 데이터**이고, 큐레이션은 **교육 깊이를 확보하는 데이터**입니다. 자동 수집된 문장을 AI가 사실처럼 확장해서 저장하지 않습니다. 자세한 내용은 Wikipedia/Wikidata 원문으로 연결합니다.

## 2. 한 사건을 어떻게 자료화하는가

권장 레코드 구조:

```json
{
  "id": "hansan-1592",
  "title": "한산도 대첩",
  "year": 1592,
  "place": "한산도",
  "country": "한국",
  "region": "동아시아",
  "lat": 34.767,
  "lon": 128.5,
  "category": "war",
  "summary": "무슨 일이 있었는지 1~2문장",
  "significance": "왜 중요한지 1~2문장",
  "people": ["이순신"],
  "relatedPlaces": ["한산도", "통영"],
  "keyPoints": ["학습 포인트 1", "학습 포인트 2", "학습 포인트 3"],
  "wikiQuery": "한산도 대첩",
  "wikiQueryEn": "Battle of Hansan Island",
  "sourceTier": "curated",
  "coordinatePrecision": "site",
  "reviewStatus": "verified"
}
```

### 자료 조사 순서

**① 사건명 정규화 → ② 날짜 확인 → ③ 장소 확인 → ④ 좌표 지정 → ⑤ 핵심 사실 1~2문장 → ⑥ 역사적 의의 → ⑦ 인물·장소 연결 → ⑧ 학습 질문/포인트 → ⑨ 출처 링크** 순서가 가장 안정적입니다.

## 3. 좌표화 원칙

역사 사건은 현대 주소처럼 정확한 한 점으로 환원되지 않는 경우가 많습니다. 그래서 TimeTrail은 `coordinatePrecision`을 반드시 함께 기록합니다.

- `site`: 전투지, 유적, 궁전, 건물처럼 특정 지점이 비교적 명확함
- `city`: 사건이 도시 전체에서 일어나 도시 대표 좌표를 사용함
- `city-or-region`: 정확한 현장을 특정하기 어려워 도시 또는 지역 중심점을 사용함
- `region`: 전쟁·이동·대유행처럼 넓은 영역을 대표 좌표로 표현함
- `approximate`: 고대 지명처럼 현대 위치를 근사함
- `unknown`: 자동 수집 후 아직 정확도를 분류하지 않음

### 좌표를 얻는 권장 순서

1. **Wikidata `P625` 좌표** 확인
2. Wikipedia 문서의 좌표 확인
3. OpenStreetMap/Nominatim에서 현대 지명 확인
4. GeoNames 등 지명 데이터로 교차 확인
5. 역사적 장소가 넓거나 논쟁적이면 특정 좌표를 억지로 고르지 말고 `region`/`approximate`로 표시

### 좌표 품질 규칙

- 위도는 `-90..90`, 경도는 `-180..180`
- 도시 중심점 좌표를 전투지 정확 좌표처럼 표시하지 않음
- 고대 도시의 위치가 추정일 경우 `approximate`
- 한 사건이 여러 장소에서 진행되면 **하나의 이벤트 + Story Pack 경로** 또는 여러 하위 이벤트로 분리
- 국경이 현재와 달랐던 시대라도 `country`는 탐색 편의를 위해 현대 지역명을 사용할 수 있으며, 설명에서 당시 정치체를 별도로 명시

## 4. 수동으로 계속 추가하는 가장 쉬운 방법

### JSON 직접 추가

`data/history-events.json` 끝에 같은 스키마의 객체를 추가합니다. 교육용 핵심 사건은 이 방식을 권장합니다.

### CSV 대량 추가

`data/history-template.csv`를 복사하여 엑셀/구글시트에서 작성합니다.

```bash
npm run data:import -- ./data/my-history.csv ./data/history-imported.json
```

CSV 필수 열:

```text
id,title,year,place,lat,lon,category
```

권장 열:

```text
country,region,summary,significance,wikiQuery,wikiQueryEn,coordinatePrecision,sourceUrl
```

## 5. Wikidata에서 대량 자동 수집

```bash
npm run data:refresh
```

`data/harvest-config.json`에서 수집 유형과 최대량을 조정합니다.

기본 대상:

- historical event
- battle
- war
- revolution
- treaty
- earthquake
- archaeological site
- castle
- palace

자동 수집 레코드는 기본적으로 다음을 저장합니다.

```text
Wikidata QID
이름/설명
날짜 또는 inception
P625 좌표
국가/장소
영문 Wikipedia 문서 링크(있는 경우)
원본 Wikidata URL
```

### 왜 한 번의 거대한 SPARQL 쿼리를 쓰지 않는가

Wikidata Query Service는 전체 Wikidata를 한 번에 덤프하는 용도가 아닙니다. 유형별로 페이지를 나누고 재시도·지연을 적용해야 timeout/429를 줄일 수 있습니다. `refresh-history.mjs`가 이 방식을 사용합니다.

## 6. GitHub에서 자동으로 계속 늘리는 방법

`.github/workflows/refresh-history.yml`은 두 방식으로 실행됩니다.

- **매주 월요일 자동 실행**
- GitHub → Actions → `Refresh historical data index` → `Run workflow` 수동 실행

수집 결과가 바뀌면 GitHub Actions bot이 다음 파일만 commit 합니다.

```text
data/history-events-index.json
data/history-events-index.meta.json
```

workflow가 수집 결과를 commit한 뒤 동일 실행에서 Pages artifact를 업로드하고 직접 재배포하므로, `GITHUB_TOKEN` push가 별도 workflow를 다시 트리거하지 않아도 새 데이터가 사이트에 반영됩니다.

## 7. 교육 품질을 높이는 큐레이션 규칙

좋은 사건 카드는 단순 정의문이 아니라 다음 5가지를 답해야 합니다.

1. **무슨 일이 있었나?**
2. **왜 이 장소에서 일어났나?** 지형·교역·정치 중심지 여부
3. **왜 중요한가?** 전후 변화
4. **누구와 무엇이 연결되는가?** 인물·장소·제도·기술
5. **동시대 다른 지역과 비교하면 무엇이 보이는가?** Time Duel에 활용

`keyPoints`에는 단순 반복문보다 “원인 / 과정 / 결과” 또는 “정치 / 경제 / 문화”처럼 서로 다른 관점을 넣는 것이 좋습니다.

## 8. 이미지 자료화 원칙

이미지는 프로젝트 저장소에 무단 복사하지 않습니다.

권장 순서:

1. Wikipedia API의 `pageimages` 썸네일
2. Wikimedia Commons 검색
3. Commons 파일 페이지에서 라이선스·저작자 확인
4. 필요하면 공개 도메인/CC 라이선스 파일만 별도 캐시

현재 앱은 사건을 열 때 Wikipedia 대표 이미지와 첫 설명을 자동 조회합니다. 네트워크가 실패해도 내장 교육 설명은 남아 있습니다.

## 9. 데이터 검토 체크리스트

새 레코드를 추가할 때 최소한 다음을 확인합니다.

- 연도가 기원전/기원후 기준에 맞는가
- 장소 이름과 현재 좌표가 일치하는가
- 도시 중심 좌표를 `site`로 오표기하지 않았는가
- 사건명 검색어로 Wikipedia/Wikidata에서 실제 항목을 찾을 수 있는가
- 설명이 원인/결과를 과도하게 단정하지 않는가
- 전쟁·학살·식민지 사건에서 피해 집단과 논쟁을 지나치게 단순화하지 않는가
- 현대 국가명을 당시 국가명과 혼동하지 않는가
- 자동 수집 레코드는 `machine-imported` 상태를 유지하는가

## 10. 데이터가 수만 건이 되었을 때

브라우저에 모든 마커를 한 번에 그리면 느려집니다. TimeTrail은 **현재 연도에 가까운 기록만 지도에 표시**하고, 전체 데이터는 검색/근접 탐색용으로 유지합니다. 수십만 건 이상이 되면 다음 단계가 필요합니다.

- 연도별 파일 분할 (`index/1500.json` 등)
- 지역별 spatial tile 또는 geohash 인덱스
- 빌드 타임 검색 인덱스
- 압축 JSON 또는 columnar 포맷
- 필요 시 CDN/정적 object storage

GitHub Pages만으로도 수만 건은 가능하지만, 수십만~수백만 건이면 한 파일에 모두 넣지 않는 것이 좋습니다.
