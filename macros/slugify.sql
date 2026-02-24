{% macro slugify(column) %}
  lower(trim(
    both '-' from regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace({{ column }}, '\+\+', '-plus-plus', 'g'),
          '#', '-sharp', 'g'
        ),
        '[^a-zA-Z0-9]+', '-', 'g'
      ),
      '-+', '-', 'g'
    )
  ))
{% endmacro %}
