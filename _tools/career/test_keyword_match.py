#!/usr/bin/env python3
"""T166 / G-04: the screen keyword matcher is token-aware, not a substring test.

Run:  python3 -m unittest discover -s _tools/career -p 'test_keyword_match.py'
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from career import screen  # noqa: E402

has = screen._has_keyword


class FalsePositives(unittest.TestCase):
    """Measured on the old squash-substring matcher (G-04)."""

    def test_django_is_not_go(self):
        self.assertFalse(has("We use Django", "Go"))

    def test_javascript_is_not_java(self):
        self.assertFalse(has("JavaScript", "Java"))

    def test_other_substring_traps(self):
        for text, kw in [("Scala developer", "Scal"), ("Reactive systems", "React"),
                         ("Typescript", "Script"), ("Rusty tools", "Rust"),
                         ("Postgresql", "Postgre"), ("Cassandra", "Cass"),
                         ("Spring", "Pring"), ("Mongo", "Go"), ("Cargo", "Go")]:
            self.assertFalse(has(text, kw), (text, kw))

    def test_c_is_not_cpp_or_csharp(self):
        self.assertFalse(has("C++ and C# services", "C"))
        self.assertFalse(has("C# services", "C++"))
        self.assertFalse(has("C++ services", "C#"))

    def test_phrase_must_be_contiguous_tokens(self):
        self.assertFalse(has("machine and deep learning", "machine learning"))


class TruePositives(unittest.TestCase):
    def test_exact_and_case(self):
        self.assertTrue(has("Services in Go and Python", "go"))
        self.assertTrue(has("Services in GO", "Go"))

    def test_punctuation_and_wrapping(self):
        self.assertTrue(has("tools: CI/CD, Docker", "CI/CD"))
        self.assertTrue(has("prompt\nengineering", "prompt engineering"))
        self.assertTrue(has("Go, Rust.", "Rust"))
        self.assertTrue(has("Go/Java", "Java"))
        self.assertTrue(has("Java-Entwickler", "Java"))

    def test_plural_both_ways(self):
        self.assertTrue(has("Vector databases", "vector database"))
        self.assertTrue(has("vector database", "vector databases"))

    def test_symbol_tokens(self):
        self.assertTrue(has("C++ and C# services", "C++"))
        self.assertTrue(has("C++ and C# services", "C#"))
        self.assertTrue(has("ASP.NET Core", ".NET"))
        self.assertTrue(has("NodeJS backend", "Node.js"))

    def test_version_suffix_is_the_same_technology(self):
        self.assertTrue(has("Python3 scripts", "Python"))
        self.assertTrue(has("Java 17", "Java"))

    def test_hyphenated_line_break(self):
        self.assertTrue(has("Kuber-\nnetes operators", "Kubernetes"))

    def test_empty_keyword_is_trivially_present(self):
        self.assertTrue(has("anything", ""))


class Synonyms(unittest.TestCase):
    def test_table_pairs_both_directions(self):
        for a, b in [("Golang", "Go"), ("k8s", "Kubernetes"),
                     ("Amazon Web Services", "AWS"), ("PostgreSQL", "Postgres"),
                     ("Google Cloud Platform", "GCP"), ("TypeScript", "TS")]:
            self.assertTrue(has(f"Experience with {a}", b), (a, b))
            self.assertTrue(has(f"Experience with {b}", a), (b, a))

    def test_synonym_does_not_leak_to_substring(self):
        self.assertFalse(has("Django and Golfing", "Golang"))
        self.assertFalse(has("The kubernetes-like k8sish", "k8s2000x"))

    def test_caller_supplied_synonyms(self):
        self.assertFalse(has("worked with LangChain", "LLM orchestration"))
        self.assertTrue(has("worked with LangChain", "LLM orchestration",
                            synonyms=[("langchain", "llm orchestration")]))


class Scripts(unittest.TestCase):
    def test_cyrillic_russian(self):
        self.assertTrue(has("Опыт: Python, Kubernetes, микросервисы", "микросервисы"))
        self.assertFalse(has("суперсервисы", "сервисы"))
        self.assertTrue(has("Разработка на Go", "Go"))
        self.assertFalse(has("Разработка на Django", "Go"))

    def test_serbian_cyrillic_and_latin(self):
        self.assertTrue(has("Искуство у Python-у и Go-у", "Go"))
        self.assertFalse(has("Iskustvo u Django okviru", "Go"))
        self.assertTrue(has("Razvoj servisa u jeziku Go", "Go"))

    def test_german(self):
        self.assertTrue(has("Berufserfahrung mit Java und Go", "Go"))
        self.assertFalse(has("Erfahrung mit Django", "Go"))
        self.assertTrue(has("Cloud-Infrastruktur auf AWS", "AWS"))

    def test_hindi_combining_marks_stay_inside_token(self):
        self.assertTrue(has("अनुभव: पायथन और Go", "पायथन"))
        self.assertFalse(has("पायथनिक", "पायथन"))

    def test_korean_particles_attach_to_the_noun(self):
        self.assertTrue(has("파이썬을 사용한 개발", "파이썬"))
        self.assertFalse(has("개발", "발"))

    def test_cjk_without_spaces_uses_substring(self):
        self.assertTrue(has("使用Python和机器学习开发服务", "机器学习"))
        self.assertFalse(has("使用Python开发服务", "机器学习"))

    def test_arabic_and_zwnj_persian(self):
        self.assertTrue(has("خبرة في Go و Python", "Go"))
        self.assertTrue(has("تجربه در می‌خواهم", "میخواهم"))


if __name__ == "__main__":
    unittest.main()
