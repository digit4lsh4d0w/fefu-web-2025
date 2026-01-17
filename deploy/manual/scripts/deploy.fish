#!/usr/bin/env fish

# Переменные среды
set -gx REPO_URL https://github.com/Digit4lSh4d0w/fefu-web-2025.git
set -gx PROJECT_ROOT /var/www/fefu-lab
set -gx DEPLOY_ROOT $PROJECT_ROOT/deploy
set -gx STATIC_ROOT $PROJECT_ROOT/static
set -gx UV_PYTHON_INSTALL_DIR $PROJECT_ROOT/.cache

function install_tools
    apt install -y curl git sudo

    curl -LsSf https://astral.sh/uv/install.sh | sh
    fish_add_path ~/.local/bin
end

function install_project_dependencies
    uv python install
    uv sync
end

function install_services
    echo "Установка PostgreSQL"
    apt install -y postgresql libpq5

    echo "Установка Nginx"
    apt install -y nginx
end

function stop_services
    echo "Остановка сервисов"
    systemctl stop postgresql.service
    systemctl stop nginx.service
    systemctl stop gunicorn.service
end

function enable_services
    echo "Перезапуск сервисов"
    systemctl enable --now postgresql.service
    systemctl enable --now nginx.service
    systemctl enable --now gunicorn.service
end

function main
    echo "Установка сервиса"

    if test (id -u) -ne 0
        echo "Ошибка: скрипт должен запускаться от имени root"
        exit 1
    end

    # Добавление статической DNS записи
    echo '127.0.0.1 fefu-django-app' >> /etc/hosts

    # Запоминание текущей директории
    set -l CWD $PWD

    apt update
    install_tools

    git clone $REPO_URL $PROJECT_ROOT
    cd $PROJECT_ROOT

    install_project_dependencies
    source .venv/bin/activate.fish

    install_services
    stop_services

    # Postgres
    cp -f $DEPLOY_ROOT/postgres/pg_hba.conf /etc/postgresql/17/main/pg_hba.conf

    # Nginx
    cp -f $DEPLOY_ROOT/nginx/fefu-lab.conf /etc/nginx/sites-available/fefu-lab.conf
    ln -sf /etc/nginx/sites-available/fefu-lab.conf /etc/nginx/sites-enabled/fefu-lab.conf

    # Gunicorn
    cp -f $DEPLOY_ROOT/gunicorn/gunicorn.service /etc/systemd/system

    systemctl daemon-reload
    enable_services
    sleep 2

    # Создание пользователя и базы данных
    sudo -u postgres psql -f $DEPLOY_ROOT/postgres/init.sql

    python $PROJECT_ROOT/src/manage.py migrate --run-syncdb
    python $PROJECT_ROOT/src/manage.py loaddata $CWD/dump.json
    python $PROJECT_ROOT/src/manage.py collectstatic --no-input --clear
    sleep 2

    # Проверка доступности
    curl --head http://fefu-django-app
end

main
