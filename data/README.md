# TimeTrail 역사 데이터

TimeTrail의 브라우저 내장 교육용 역사 데이터입니다.

- `history-data.js`: 웹앱에서 직접 사용하는 데이터 모듈
- `history-events.json`: 사건 데이터 JSON 사본
- `story-packs.json`: 교육용 스토리 경로
- `cities.json`: Time Duel 도시 목록

각 사건에는 연도, 좌표, 국가/지역, 간단한 사실 요약, 역사적 의미, 관련 인물·장소, 핵심 학습 포인트, Wikipedia 검색어가 들어 있습니다.

상세 설명과 이미지는 브라우저에서 Wikimedia/MediaWiki 공개 API를 조회하여 보강합니다. 네트워크 요청이 실패해도 정적 교육용 요약과 학습 포인트는 그대로 표시됩니다.

외부 문서 링크는 한국어/영어 Wikipedia, Wikidata, 나무위키 검색, Wikimedia Commons 이미지 검색으로 연결합니다. 외부 문서와 이미지는 각 사이트의 최신 내용 및 해당 라이선스를 따릅니다.
