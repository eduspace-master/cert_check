# SSL 인증서 모니터링 도구

이 도구는 지정된 도메인 목록의 SSL 인증서를 모니터링하고 만료 정보를 정기적으로 이메일로 보고합니다.

## 주요 기능

- 여러 도메인의 SSL 인증서 만료일 자동 모니터링
- 와일드카드 인증서 탐지 및 표시
- 인증서 만료까지 남은 일수 계산
- 평일(월-금) 자동 이메일 보고서 발송
- 모든 시간 표시를 한국어 기준 24시간 형식으로 통일

## 설치 방법

1. 필수 패키지 설치
   ```bash
   sudo apt update
   sudo apt install openssl sendmail
   ```

2. 디렉토리 구조 설정
   ```bash
   mkdir -p ~/cert_check/log ~/cert_check/tmp
   ```

3. 도메인 목록 설정
   ```bash
   # ~/cert_check/domain-list.txt 파일에 모니터링할 도메인을 한 줄에 하나씩 작성
   ```

4. 실행 권한 설정
   ```bash
   chmod +x ~/cert_check/cert_check.sh
   ```

5. Crontab 설정 (평일 오전 9시 자동 실행)
   ```bash
   crontab -e
   # 다음 내용 추가: 0 9 * * 1-5 /bin/bash $HOME/cert_check/cert_check.sh
   ```

## 사용 방법

- 수동 실행: `~/cert_check/cert_check.sh`
- 자동 실행: cron 설정에 따라 평일 오전 9시마다 자동 실행됨

## 출력 예시

```
보고서 생성 시간: 2025-05-07 09:00 수

도메인명                SSL 만료일                남은 일수       인증서 유형
-------------------------------------------------------------
example.com              2025-07-01 18:06 화      55일 남음       일반 인증서
sub.example.com          2025-07-09 00:24 수      62일 남음       일반 인증서
another-domain.com       2025-08-04 04:53 월      88일 남음       와일드카드 인증서
```

## 설정 옵션

스크립트의 다음 변수들을 필요에 따라 수정할 수 있습니다:

- `EMAIL`: 보고서를 받을 이메일 주소
- `DOMAINS_FILE`: 모니터링할 도메인 목록 파일
- `LOG_PATH`: 로그 파일이 저장될 경로
- `TMP_PATH`: 임시 파일이 저장될 경로

## 문제 해결

- **이메일이 발송되지 않는 경우**: sendmail 설정 확인
- **SSL 정보가 없는 경우**: 도메인 HTTPS 설정 확인
- **cron이 실행되지 않는 경우**: 시스템 로그 확인 (`grep CRON /var/log/syslog`)

## 로그 및 보고서 위치

- 스크립트 로그: `~/cert_check/log/domain_check.log`
- 임시 보고서: `~/cert_check/tmp/domain_report.txt`

## 라이선스

MIT
