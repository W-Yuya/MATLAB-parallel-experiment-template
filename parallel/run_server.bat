@echo off
setlocal

IF "%~1"=="" (
    ECHO �G���[: ���s�������f�B���N�g�����w�肵�Ă��������B
    ECHO ��: run_server.bat C:\Your\Project\Directory
    GOTO :EOF
)

SET TARGET_DIR=%~1

IF NOT EXIST "%TARGET_DIR%" (
    ECHO �G���[: �w�肳�ꂽ�f�B���N�g�� "%TARGET_DIR%" �͑��݂��܂���B
    GOTO :EOF
)

CD "%TARGET_DIR%"

IF %ERRORLEVEL% NEQ 0 (
    ECHO �G���[: �f�B���N�g�� "%TARGET_DIR%" �ւ̈ړ��Ɏ��s���܂����B
    GOTO :EOF
)

ECHO �f�B���N�g���� "%CD%" �ɕύX���܂����B

IF NOT EXIST ".\venv\Scripts\python.exe" (
    ECHO �G���[: ���z����������܂���ł��� �B
    GOTO :EOF
)

.\venv\Scripts\python.exe server.py
IF %ERRORLEVEL% NEQ 0 (
    ECHO �G���[: server.py �̎��s�Ɏ��s���܂����B
    GOTO :EOF
)

endlocal