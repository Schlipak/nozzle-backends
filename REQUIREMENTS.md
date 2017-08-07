Backend scripts dependencies
============================

## Applications

Requires the `fuzzystringmatch` gem, install using:

```sh
gem install fuzzy-string-match
```

If the script crashes in Nozzle, you might be using RVM or other Ruby version management systems. Please check your ENV for the GEM_HOME and GEM_PATH variables, and include them in your NozzleLauncher.conf

## Google-Search

No special requirement

## Launches

No special requirement

## Math

Requires the python package `PyExpressionEval`, install using:

```sh
pip install py_expression_eval
```

## Web

Requires the `request` and `html-entities` Node modules, install in the script directory using:

```sh
npm i request html-entities
```
