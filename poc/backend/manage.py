#!/usr/bin/env python
"""Django의 관리 작업을 위한 커맨드라인 유틸리티."""
import os
import sys


def main():
    """관리 작업 실행."""
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Django를 임포트할 수 없습니다. 설치되어 있고 "
            "PYTHONPATH 환경변수에 포함되어 있는지 확인하세요. "
            "가상환경을 활성화하는 것을 잊지 않았나요?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == "__main__":
    main()
