#!/bin/sh

STUBBY="stubby"
CONF="/etc/stubby/stubby.yml"

C="\033[36m"
G="\033[32m"
Y="\033[33m"
R="\033[31m"
N="\033[0m"

pause() {
    echo
    printf "Нажмите Enter..."
    read -r _
}

installed() {
    apk info -e stubby >/dev/null 2>&1
}

running() {
    /etc/init.d/stubby running >/dev/null 2>&1
}

header() {
    clear 2>/dev/null || true

    echo
    printf "${C}╔══════════════════════════════════════════════════╗${N}\n"
    printf "${C}║${N}                 DNS MENU                       ${C}║${N}\n"
    printf "${C}╚══════════════════════════════════════════════════╝${N}\n"
    echo
}

install_dot() {
    header

    echo "Установка DoT / Stubby"
    echo

    if installed; then
        echo "${Y}Stubby уже установлен.${N}"
        pause
        return
    fi

    apk update || {
        echo "${R}apk update ошибка.${N}"
        pause
        return
    }

    apk add stubby || {
        echo "${R}Не удалось установить Stubby.${N}"
        pause
        return
    }

    echo
    echo "${G}Stubby установлен.${N}"
    echo
    echo "Конфигурация:"
    echo "$CONF"

    pause
}

start_dot() {
    if ! installed; then
        echo "${Y}Stubby не установлен.${N}"
        pause
        return
    fi

    /etc/init.d/stubby enable
    /etc/init.d/stubby start

    echo "${G}Stubby запущен.${N}"

    pause
}

stop_dot() {
    if ! installed; then
        pause
        return
    fi

    /etc/init.d/stubby stop

    echo "${G}Stubby остановлен.${N}"

    pause
}

remove_dot() {
    header

    if ! installed; then
        echo "Stubby не установлен."
        pause
        return
    fi

    printf "Удалить Stubby? [y/N]: "
    read -r a

    case "$a" in
        y|Y|д|Д)
            /etc/init.d/stubby stop >/dev/null 2>&1 || true
            /etc/init.d/stubby disable >/dev/null 2>&1 || true

            apk del stubby

            rm -rf /etc/stubby

            echo "${G}Stubby удалён.${N}"
            ;;
    esac

    pause
}

status_dot() {
    header

    echo "Stubby:"
    echo

    if installed; then
        echo "${G}УСТАНОВЛЕН${N}"

        if running; then
            echo "${G}RUNNING${N}"
        else
            echo "${Y}STOPPED${N}"
        fi
    else
        echo "${R}НЕ УСТАНОВЛЕН${N}"
    fi

    echo

    if [ -f "$CONF" ]; then
        echo "Config:"
        echo "$CONF"
    fi

    pause
}

dns_main() {
    while true; do
        header

        echo " 1) Установить DoT / Stubby"
        echo " 2) Запустить Stubby"
        echo " 3) Остановить Stubby"
        echo " 4) Статус"
        echo " 5) Удалить Stubby"
        echo
        echo " 0) Назад"
        echo

        printf "Выбор: "
        read -r c

        case "$c" in
            1) install_dot ;;
            2) start_dot ;;
            3) stop_dot ;;
            4) status_dot ;;
            5) remove_dot ;;
            0|"") return ;;
            *) echo "${Y}Неверный выбор.${N}"; sleep 1 ;;
        esac
    done
}

dns_main
