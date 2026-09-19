"""Read the ASCII property-list syntax emitted by XcodeGen without macOS tools."""
import json
import re
from pathlib import Path

_TOKEN = re.compile(r'\s+|/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', re.S)


def load_project(path: Path) -> dict:
    tokens = [m.group() for m in _TOKEN.finditer(path.read_text())
              if not m.group().isspace() and not m.group().startswith(('/*', '//'))]
    index = 0

    def take(expected=None):
        nonlocal index
        if index >= len(tokens):
            raise ValueError('Unexpected end of project')
        token = tokens[index]
        index += 1
        if expected is not None and token != expected:
            raise ValueError(f'Expected {expected!r}, found {token!r}')
        return token

    def value():
        token = take()
        if token == '{':
            result = {}
            while tokens[index] != '}':
                key = value()
                take('=')
                if key in result:
                    raise ValueError(f'Duplicate project key {key}')
                result[key] = value()
                take(';')
            take('}')
            return result
        if token == '(':
            result = []
            while tokens[index] != ')':
                result.append(value())
                if tokens[index] == ',': take(',')
                elif tokens[index] != ')': raise ValueError('Missing array comma')
            take(')')
            return result
        return json.loads(token) if token.startswith('"') else token

    result = value()
    if index != len(tokens) or not isinstance(result, dict):
        raise ValueError('Invalid project document')
    return result
