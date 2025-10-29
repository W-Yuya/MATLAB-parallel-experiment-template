@echo off
setlocal

IF "%~1"=="" (
    ECHO エラー: 実行したいディレクトリを指定してください。
    ECHO 例: run_server.bat C:\Your\Project\Directory
    GOTO :EOF
)

SET TARGET_DIR=%~1

IF NOT EXIST "%TARGET_DIR%" (
    ECHO エラー: 指定されたディレクトリ "%TARGET_DIR%" は存在しません。
    GOTO :EOF
)

CD "%TARGET_DIR%"

IF %ERRORLEVEL% NEQ 0 (
    ECHO エラー: ディレクトリ "%TARGET_DIR%" への移動に失敗しました。
    GOTO :EOF
)

ECHO ディレクトリを "%CD%" に変更しました。

call venv\Scripts\activate
IF %ERRORLEVEL% NEQ 0 (
    ECHO エラー: 仮想環境のアクティベートに失敗しました。
    GOTO :EOF
)

python server.py
IF %ERRORLEVEL% NEQ 0 (
    ECHO エラー: server.py の実行に失敗しました。
    GOTO :EOF
)

endlocal