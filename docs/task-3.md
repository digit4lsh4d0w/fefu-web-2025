# Задание №3

- Создать несколько моделей данных:
  - Студент.
  - Курс.
  - Преподаватель.
  - Запись на курс.
- Взаимодействовать с базой только с использованием `ORM`.
- Добавить отображение моделей в панели администратора.
- Интегрировать новую функциональность не нарушая существующую.

## Критерии оценивания

- [x] Корректные модели и отношения между ними
- [x] Правильные типы полей и валидация
- [x] Настроена интеграция моделей в панель администрирования
- [x] Настроены поиск и фильтрация в панели администрирования
- [x] Настроено читаемое отображение объектов
- [x] Обновлены существующие представления
- [x] ORM
- [x] Обработка ошибок

## Отчет

### Модели данных

#### Абстрактные модели

Для следования принципу `DRY` я выделил часто повторяющиеся поля
и методы в отдельные абстрактные классы:

```python
class AbstractModel(models.Model):
    is_active = models.BooleanField(default=True, verbose_name="Активен")
    created_at = models.DateTimeField(auto_now_add=True, verbose_name="Дата создания")
    updated_at = models.DateTimeField(auto_now=True, verbose_name="Дата обновления")

    class Meta:
        abstract = True

    @property
    def is_active_display(self):
        if self.is_active:
            return "Да"
        return "Нет"


class AbstractUser(AbstractModel):
    first_name = models.CharField(max_length=20, verbose_name="Имя")
    last_name = models.CharField(max_length=50, verbose_name="Фамилия")
    email = models.EmailField(max_length=50, unique=True, verbose_name="Email")
    birthday = models.DateField(null=True, blank=True, verbose_name="Дата рождения")

    class Meta:
        abstract = True
        ordering = ["last_name", "first_name"]
        unique_together = ["first_name", "last_name", "birthday"]

    def __str__(self):
        return f"{self.last_name} {self.first_name}"

    @property
    def full_name(self):
        return str(self)
```

Таким образом мне не придется везде прописывать общие поля, такие как:

- Дата создания или обновления.
- Флаг активности.
- Имя и фамилия человека.
- Дата рождения человека.
- Адрес электронной почты человека.

#### Студент

Студент расширяет класс абстрактного пользователя дополнительными полями
для обозначения факультета:

```python
@final
class Student(AbstractUser):
    FACULTY_CHOICES = {
        "CS": "Кибербезопасность",
        "SE": "Программная инженерия",
        "IT": "Информационные технологии",
        "DS": "Наука о данных",
        "WEB": "Веб-технологии",
    }

    faculty = models.CharField(
        max_length=4,
        choices=FACULTY_CHOICES,
        default="CS",
        verbose_name="Факультет",
    )

    @final
    class Meta:
        verbose_name = "Студент"
        verbose_name_plural = "Студенты"
        unique_together = ["first_name", "last_name", "birthday", "faculty"]
        db_table = "students"

    def get_absolute_url(self):
        return reverse("student_detail", kwargs={"pk": self.pk})

    def faculty_display(self):
        return self.FACULTY_CHOICES.get(self.faculty, "Неизвестно")
```

#### Преподаватель

Класс преподавателя вообще ничем не отличается от абстрактного пользователя,
кроме метаданных:

```python
@final
class Teacher(AbstractUser):
    @final
    class Meta:
        verbose_name = "Преподаватель"
        verbose_name_plural = "Преподаватели"
        unique_together = ["first_name", "last_name", "birthday"]
        db_table = "teachers"
```

#### Курс

Курс сильно не отличается от уже существующих моделей:

```python
@final
class Course(AbstractModel):
    title = models.CharField(max_length=200, unique=True, verbose_name="Название")
    slug = models.SlugField(max_length=200, unique=True, verbose_name="Машиночитаемое название")
    description = models.CharField(max_length=1500, verbose_name="Описание")
    duration = models.PositiveIntegerField(verbose_name="Продолжительность курса (в минутах)")
    teacher = models.ForeignKey(
        Teacher,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        verbose_name="Преподаватель",
    )

    @final
    class Meta:
        verbose_name = "Курс"
        verbose_name_plural = "Курсы"
        ordering = ["title"]
        db_table = "courses"

    def __str__(self):
        return self.title

    @property
    def teacher_display(self):
        if self.teacher:
            return str(self.teacher)
        return "Преподаватель не назначен"
```

Дополнительно указывается, что если из связанной таблицы преподавателей
удаляется запись, то в таблице курсов поле преподавателя просто
будем пустым, хотя сама запись останется в базе данных.

#### Запись на курс

Запись на курс - промежуточная таблица, позволяющаяя реализовать отношение
"много ко многим".

```python
@final
class Enrollment(AbstractModel):
    student = models.ForeignKey(
        Student,
        on_delete=models.CASCADE,
        verbose_name="Студент",
    )
    course = models.ForeignKey(
        Course,
        on_delete=models.CASCADE,
        verbose_name="Курс",
    )

    @final
    class Meta:
        verbose_name = "Зачисление"
        verbose_name_plural = "Зачисления"
        ordering = ["course", "is_active", "student"]
        db_table = "enrollments"

    def __str__(self):
        return str(self.course)
```

Запись будет удалена, если будет удален связанный объект из таблицы
курсов или студентов.

### Отношения между таблицами

Как можно было заметить - отношения между таблицами задаются с
помощью `models.ForeignKey()`.

Что делать с полем, если из связаной таблицы были удалены данные,
задает параметр `on_delete`.

### Валидация

Валидация производится по сути дважды - при получении данных из формы
и при добавлении данных в базу данных.

Валидация на уникальность записи на курс:

```python
def clean(self):
    cleaned_data = super().clean()

    student = cleaned_data.get("student")
    course = cleaned_data.get("course")

    if (
        student
        and course
        and Enrollment.objects.filter(student=student, course=course, is_active=True).exists()
    ):
        self.add_error("course", "Студент уже зачислен на курс")

    return cleaned_data
```

### Интеграция с Django Admin

Регистрация управления таблицей в `Django Admin` производится очень
просто:

```python
@admin.register(Enrollment)
class EnrollmentAdmin(admin.ModelAdmin):
    list_display = [
        "course",
        "student",
        "is_active",
        "created_at",
    ]

    list_filter = [
        "course",
        "is_active",
        "student",
    ]

    search_fields = [
        "course",
        "student",
    ]
```

Нужно просто указать поля, которые будут отображаться, по которым
можно производить фильтрацию и по которым можно производить поиск.

### Человекочитаемое представление моделей данных

Реализуется максимально просто, нужно просто задать метод
`__str__()`:

Пример строчного представления для абстрактного пользователя:

```python
def __str__(self):
    return f"{self.last_name} {self.first_name}"
```

### Остальное

Голых `SQL` запросов в коде приложения нет - вся выборка производится
путем использования встроенных методов, например:

```python
Course.objects.filter(is_active=True).order_by("-created_at")[:5]
```

Обработка ошибок реализована подходящим способом, который позволяет
пользователю увидеть человеческое описание ошибки:

```python
form.add_error("role", "Выбрана некорректная роль")
```

<details>
  <summary>Скриншоты</summary>
  <h4>Главная страница</h4>
  <a href="../assets/task-3/index.webp">
    <img src="../assets/task-3/index.webp" width="600"/>
  </a>
  <h4>Регистрация</h4>
  <a href="../assets/task-3/registration.webp">
    <img src="../assets/task-3/registration.webp" width="600"/>
  </a>
  <h4>Регистрация как студент</h4>
  <a href="../assets/task-3/registration-as-student.webp">
    <img src="../assets/task-3/registration-as-student.webp" width="600"/>
  </a>
  <h4>Список курсов</h4>
  <a href="../assets/task-3/course-list.webp">
    <img src="../assets/task-3/course-list.webp" width="600"/>
  </a>
  <h4>Подробности о курсе</h4>
  <a href="../assets/task-3/course-details.webp">
    <img src="../assets/task-3/course-details.webp" width="600"/>
  </a>
  <h4>Подробности о студенте</h4>
  <a href="../assets/task-3/student-details.webp">
    <img src="../assets/task-3/student-details.webp" width="600"/>
  </a>
  <h4>Django Admin - таблицы</h4>
  <a href="../assets/task-3/django-admin-tables.webp">
    <img src="../assets/task-3/django-admin-tables.webp" width="600"/>
  </a>
  <h4>Django Admin - список студентов</h4>
  <a href="../assets/task-3/django-admin-students.webp">
    <img src="../assets/task-3/django-admin-students.webp" width="600"/>
  </a>
</details>
