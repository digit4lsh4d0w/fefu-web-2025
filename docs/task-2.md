# Задание №2

- Создать несколько маршрутов (`routes`):
  - `/feedback/` - статический маршрут для формы обратной связи.
  - `/registration/` - статический маршрут для формы регистрации пользователей.
- Формы должны быть защищены от CSRF атак.
- Для всех форм должна быть реализована проверка данных на стороне сервера.
- Для всех страниц должны использоваться HTML-шаблоны.
- Статические файлы (CSS, JS, изображения) должны находиться в директории `static`.
- Интегрировать новую функциональность не изменяя существующую.

## Критерии оценивания

- [x] Подготовлены шаблоны для всех страниц
- [x] Статические файлы вынесены в отдельную директорию
- [x] Форма обратной связи работает корректно
- [x] Форма регистрации работает корректно
- [x] Проверка данных на стороне сервера
- [x] Реализована защита от CSRF атак
- [x] Существующая функциональность не нарушена
- [x] Единый стиль всех страниц

## Отчет

### Представления

Реализованы следующие представления:

- `/feedback` - Форма обратной связи.
- `/registration` - Форма регистрации пользователей.

Представления реализованы как функции, использующие шаблоны `feedback.html`
и `registration.html`.

Сами функции используют классы форм, в которых заданы правила
валидации данных.

<details>
  <summary>Скриншоты</summary>
  <h4>Форма обратной связи</h4>
  <a href="../assets/task-2/feedback-form.webp">
    <img src="../assets/task-2/feedback-form.webp" width="600"/>
  </a>
  <h4>Форма регистрации</h4>
  <a href="../assets/task-2/registration-form.webp">
    <img src="../assets/task-2/registration-form.webp" width="600"/>
  </a>
</details>

### CSRF

Во всех формах с помощью стандартных средств Django (CSRF middleware)
реализована защита от CSRF атак.

Сначала CSRF токен был заменен на строку `some-csrf-payload`. При отправке
данных формы Django сообщил об ошибке валидации длины CSRF токена.

<details>
  <summary>Скриншоты</summary>
  <h4>Оригинальный CSRF токен</h4>
  <a href="../assets/task-2/devtools-csrf-showup.webp">
    <img src="../assets/task-2/devtools-csrf-showup.webp" width="600"/>
  </a>
  <h4>Измененный CSRF токен</h4>
  <a href="../assets/task-2/devtools-csrf-invalid-payload-showup.webp">
    <img src="../assets/task-2/devtools-csrf-invalid-payload-showup.webp" width="600"/>
  </a>
  <h4>Ошибка валидации длины CSRF токена</h4>
  <a href="../assets/task-2/csrf-length-mismatch.webp">
    <img src="../assets/task-2/csrf-length-mismatch.webp" width="600"/>
  </a>
</details>

Далее CSRF токен был возвращен и незначительно изменен (изменил регистр символов).
При отправке данных Django сообщил, что CSRF токен недействительный.

<details>
  <summary>Скриншоты</summary>
  <h4>Ошибка валидации CSRF токена</h4>
  <a href="../assets/task-2/csrf-incorrect-token.webp">
    <img src="../assets/task-2/csrf-incorrect-token.webp" width="600"/>
  </a>
</details>

### Валидация на стороне сервера

Валидация данных реализована в основном стандартными средствами Django.

Для этого в форме задаются следующие параметры:

- Поле обязательное или необязательное.
- Минимальная длина.
- Максимальная длина.

Дополнительная валидация реализована с помощью функций `clean` и `clean_*`.

Например, проверка сложности пароля реализована следующим образом:

```python
def clean_password(self):
    password = self.cleaned_data.get("password")
    has_digit = any(ch.isdigit() for ch in password)
    has_lower = any(ch.islower() for ch in password)
    has_upper = any(ch.isupper() for ch in password)

    if not all((has_digit, has_lower, has_upper)):
        msg = [
            "Пароль слишком простой.",
            "Пароль должен содержать:",
            "1. Хотя бы одну прописную букву.",
            "2. Хотя бы одну заглавную букву.",
            "3. Хотя бы одну цифру.",
        ]
        self.add_error("password", msg)

    return password
```

А проверка совпадения пароля и подтверждения пароля реализована так:

```python
def clean(self):
    cleaned_data = super().clean()
    password = cleaned_data.get("password")
    password_confirm = cleaned_data.get("password_confirm")
    if password != password_confirm:
        self.add_error("password_confirm", "Пароли не совпадают")
    return cleaned_data
```

При несоответствии требованиям пользователя перенаправляют на эту же
страницу, где ему дополнительно сообщается в чем заключается ошибка.

<details>
  <summary>Скриншоты</summary>
  <h4>Сообщение об ошибках</h4>
  <a href="../assets/task-2/incorrect-form-data.webp">
    <img src="../assets/task-2/incorrect-form-data.webp" width="600"/>
  </a>
</details>

Если же данные, предоставленные пользователем, прошли проверку,
то его перенаправляют на главную страницу, где ему дополнительно
сообщается о том, что его действие завершилось успешно

<details>
  <summary>Скриншоты</summary>
  <h4>Сообщение об успехе</h4>
  <a href="../assets/task-2/success-message.webp">
    <img src="../assets/task-2/success-message.webp" width="600"/>
  </a>
</details>

### Тесты

Для автоматической проверки правильности валидации данных в формах
обратной связи и регистрации были написаны unit-тесты.

### Остальное

Уже в первой версии работы статические файлы были помещены в
директорию `static`.

Существующая функциональность не была нарушена.

### Результат

В результате второго задания было получено улучшенное приложение,
использующее возможности фреймворка `Django`.

Ключевая функциональность:

- Валидация данных из форм.
