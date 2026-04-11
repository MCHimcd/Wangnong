/**
 * MarkdownParser — 轻量级 Markdown 解析器
 * 将 Markdown 文本解析为类型化的块级/行内节点数组，供 UI 渲染。
 * 支持：标题、无序/有序列表、代码块、引用、粗体、斜体、行内代码、粗斜体。
 */

export class MarkdownSegment {
  type: 'text' | 'bold' | 'italic' | 'code' | 'boldItalic' = 'text';
  content: string = '';
}

export class MarkdownBlock {
  type: 'paragraph' | 'heading' | 'listItem' | 'codeBlock' | 'orderedListItem' | 'blockquote' = 'paragraph';
  level: number = 0;
  segments: MarkdownSegment[] = [];
  content: string = '';
  language: string = '';
}

export class MarkdownParser {
  static parse(markdown: string): MarkdownBlock[] {
    if (markdown.length === 0) {
      return [];
    }

    const lines: string[] = markdown.split('\n');
    const blocks: MarkdownBlock[] = [];
    let i: number = 0;

    while (i < lines.length) {
      const line: string = lines[i];

      // 空行跳过
      if (line.trim().length === 0) {
        i++;
        continue;
      }

      // 代码块
      if (line.trimStart().startsWith('```')) {
        const codeResult = MarkdownParser.parseCodeBlock(lines, i);
        blocks.push(codeResult.block);
        i = codeResult.nextIndex;
        continue;
      }

      // 标题
      if (MarkdownParser.isHeading(line)) {
        blocks.push(MarkdownParser.parseHeading(line));
        i++;
        continue;
      }

      // 无序列表
      if (MarkdownParser.isUnorderedList(line)) {
        const block = new MarkdownBlock();
        block.type = 'listItem';
        const text: string = MarkdownParser.stripListMarker(line);
        block.segments = MarkdownParser.parseInline(text);
        blocks.push(block);
        i++;
        continue;
      }

      // 有序列表
      if (MarkdownParser.isOrderedList(line)) {
        const block = new MarkdownBlock();
        block.type = 'orderedListItem';
        const text: string = MarkdownParser.stripOrderedListMarker(line);
        block.segments = MarkdownParser.parseInline(text);
        blocks.push(block);
        i++;
        continue;
      }

      // 引用
      if (line.trimStart().startsWith('> ')) {
        const block = new MarkdownBlock();
        block.type = 'blockquote';
        const text: string = line.trimStart().substring(2);
        block.segments = MarkdownParser.parseInline(text);
        blocks.push(block);
        i++;
        continue;
      }

      // 普通段落
      const block = new MarkdownBlock();
      block.type = 'paragraph';
      block.segments = MarkdownParser.parseInline(line);
      blocks.push(block);
      i++;
    }

    return blocks;
  }

  private static isHeading(line: string): boolean {
    const trimmed: string = line.trimStart();
    if (trimmed.startsWith('# ')) {
      return true;
    }
    if (trimmed.startsWith('## ')) {
      return true;
    }
    if (trimmed.startsWith('### ')) {
      return true;
    }
    if (trimmed.startsWith('#### ')) {
      return true;
    }
    if (trimmed.startsWith('##### ')) {
      return true;
    }
    if (trimmed.startsWith('###### ')) {
      return true;
    }
    return false;
  }

  private static parseHeading(line: string): MarkdownBlock {
    const block = new MarkdownBlock();
    block.type = 'heading';
    const trimmed: string = line.trimStart();
    let level: number = 0;
    while (level < trimmed.length && level < 6 && trimmed.charAt(level) === '#') {
      level++;
    }
    block.level = level;
    const text: string = trimmed.substring(level).trim();
    block.segments = MarkdownParser.parseInline(text);
    return block;
  }

  private static isUnorderedList(line: string): boolean {
    const trimmed: string = line.trimStart();
    if (trimmed.startsWith('- ')) {
      return true;
    }
    if (trimmed.startsWith('* ')) {
      return true;
    }
    return false;
  }

  private static stripListMarker(line: string): string {
    const trimmed: string = line.trimStart();
    return trimmed.substring(2);
  }

  private static isOrderedList(line: string): boolean {
    const trimmed: string = line.trimStart();
    let idx: number = 0;
    while (idx < trimmed.length && trimmed.charAt(idx) >= '0' && trimmed.charAt(idx) <= '9') {
      idx++;
    }
    if (idx > 0 && idx < trimmed.length - 1 && trimmed.charAt(idx) === '.' && trimmed.charAt(idx + 1) === ' ') {
      return true;
    }
    return false;
  }

  private static stripOrderedListMarker(line: string): string {
    const trimmed: string = line.trimStart();
    let idx: number = 0;
    while (idx < trimmed.length && trimmed.charAt(idx) >= '0' && trimmed.charAt(idx) <= '9') {
      idx++;
    }
    // skip ". "
    return trimmed.substring(idx + 2);
  }

  private static parseCodeBlock(lines: string[], startIndex: number): CodeBlockResult {
    const result = new CodeBlockResult();
    const firstLine: string = lines[startIndex].trimStart();
    const lang: string = firstLine.substring(3).trim();

    const block = new MarkdownBlock();
    block.type = 'codeBlock';
    block.language = lang;

    const codeLines: string[] = [];
    let j: number = startIndex + 1;
    while (j < lines.length) {
      if (lines[j].trimStart().startsWith('```')) {
        j++;
        break;
      }
      codeLines.push(lines[j]);
      j++;
    }
    block.content = codeLines.join('\n');
    result.block = block;
    result.nextIndex = j;
    return result;
  }

  static parseInline(text: string): MarkdownSegment[] {
    const segments: MarkdownSegment[] = [];
    let i: number = 0;
    let buffer: string = '';

    while (i < text.length) {
      // 行内代码 `...`
      if (text.charAt(i) === '`') {
        if (buffer.length > 0) {
          segments.push(MarkdownParser.makeSegment('text', buffer));
          buffer = '';
        }
        const end: number = text.indexOf('`', i + 1);
        if (end !== -1) {
          segments.push(MarkdownParser.makeSegment('code', text.substring(i + 1, end)));
          i = end + 1;
          continue;
        }
      }

      // 粗斜体 ***...***
      if (i + 2 < text.length && text.charAt(i) === '*' && text.charAt(i + 1) === '*' && text.charAt(i + 2) === '*') {
        if (buffer.length > 0) {
          segments.push(MarkdownParser.makeSegment('text', buffer));
          buffer = '';
        }
        const end: number = text.indexOf('***', i + 3);
        if (end !== -1) {
          segments.push(MarkdownParser.makeSegment('boldItalic', text.substring(i + 3, end)));
          i = end + 3;
          continue;
        }
      }

      // 粗体 **...**
      if (i + 1 < text.length && text.charAt(i) === '*' && text.charAt(i + 1) === '*') {
        if (buffer.length > 0) {
          segments.push(MarkdownParser.makeSegment('text', buffer));
          buffer = '';
        }
        const end: number = text.indexOf('**', i + 2);
        if (end !== -1) {
          segments.push(MarkdownParser.makeSegment('bold', text.substring(i + 2, end)));
          i = end + 2;
          continue;
        }
      }

      // 斜体 *...*
      if (text.charAt(i) === '*') {
        if (buffer.length > 0) {
          segments.push(MarkdownParser.makeSegment('text', buffer));
          buffer = '';
        }
        const end: number = text.indexOf('*', i + 1);
        if (end !== -1) {
          segments.push(MarkdownParser.makeSegment('italic', text.substring(i + 1, end)));
          i = end + 1;
          continue;
        }
      }

      buffer += text.charAt(i);
      i++;
    }

    if (buffer.length > 0) {
      segments.push(MarkdownParser.makeSegment('text', buffer));
    }

    return segments;
  }

  private static makeSegment(type: 'text' | 'bold' | 'italic' | 'code' | 'boldItalic', content: string): MarkdownSegment {
    const seg = new MarkdownSegment();
    seg.type = type;
    seg.content = content;
    return seg;
  }
}

class CodeBlockResult {
  block: MarkdownBlock = new MarkdownBlock();
  nextIndex: number = 0;
}
