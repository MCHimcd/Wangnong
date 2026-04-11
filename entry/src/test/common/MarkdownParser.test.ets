import { describe, it, expect } from '@ohos/hypium';
import { MarkdownParser, MarkdownBlock, MarkdownSegment } from '../../main/ets/common/MarkdownParser';

export default function markdownParserTest() {
  describe('MarkdownParser', () => {

    // ===== 空输入 =====
    it('empty_string_returns_empty_array', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('');
      expect(blocks.length).assertEqual(0);
    });

    // ===== 纯文本 =====
    it('plain_text_returns_single_paragraph', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('Hello world');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('paragraph');
      expect(blocks[0].segments.length).assertLarger(0);
      expect(blocks[0].segments[0].content).assertEqual('Hello world');
      expect(blocks[0].segments[0].type).assertEqual('text');
    });

    // ===== 标题 =====
    it('h1_heading_parsed_correctly', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('# 标题一');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('heading');
      expect(blocks[0].level).assertEqual(1);
      expect(blocks[0].segments[0].content).assertEqual('标题一');
    });

    it('h2_heading_parsed_correctly', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('## 标题二');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('heading');
      expect(blocks[0].level).assertEqual(2);
      expect(blocks[0].segments[0].content).assertEqual('标题二');
    });

    it('h3_heading_parsed_correctly', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('### 标题三');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('heading');
      expect(blocks[0].level).assertEqual(3);
    });

    // ===== 无序列表 =====
    it('dash_list_item_parsed', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('- 列表项');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('listItem');
      expect(blocks[0].segments[0].content).assertEqual('列表项');
    });

    it('asterisk_list_item_parsed', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('* 列表项');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('listItem');
    });

    // ===== 有序列表 =====
    it('ordered_list_item_parsed', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('1. 第一项');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('orderedListItem');
      expect(blocks[0].segments[0].content).assertEqual('第一项');
    });

    // ===== 代码块 =====
    it('code_block_parsed', 0, () => {
      const md: string = '```js\nconsole.log("hi");\n```';
      const blocks: MarkdownBlock[] = MarkdownParser.parse(md);
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('codeBlock');
      expect(blocks[0].language).assertEqual('js');
      expect(blocks[0].content).assertEqual('console.log("hi");');
    });

    it('code_block_no_language', 0, () => {
      const md: string = '```\nsome code\n```';
      const blocks: MarkdownBlock[] = MarkdownParser.parse(md);
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('codeBlock');
      expect(blocks[0].language).assertEqual('');
      expect(blocks[0].content).assertEqual('some code');
    });

    // ===== 引用 =====
    it('blockquote_parsed', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('> 这是引用');
      expect(blocks.length).assertEqual(1);
      expect(blocks[0].type).assertEqual('blockquote');
      expect(blocks[0].segments[0].content).assertEqual('这是引用');
    });

    // ===== 行内格式：粗体 =====
    it('bold_inline_parsed', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('这是**粗体**文本');
      expect(blocks.length).assertEqual(1);
      const segs: MarkdownSegment[] = blocks[0].segments;
      expect(segs.length).assertEqual(3);
      expect(segs[0].type).assertEqual('text');
      expect(segs[0].content).assertEqual('这是');
      expect(segs[1].type).assertEqual('bold');
      expect(segs[1].content).assertEqual('粗体');
      expect(segs[2].type).assertEqual('text');
      expect(segs[2].content).assertEqual('文本');
    });

    // ===== 行内格式：斜体 =====
    it('italic_inline_parsed', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('这是*斜体*文本');
      expect(blocks.length).assertEqual(1);
      const segs: MarkdownSegment[] = blocks[0].segments;
      expect(segs.length).assertEqual(3);
      expect(segs[1].type).assertEqual('italic');
      expect(segs[1].content).assertEqual('斜体');
    });

    // ===== 行内格式：行内代码 =====
    it('inline_code_parsed', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('使用 `console.log` 调试');
      expect(blocks.length).assertEqual(1);
      const segs: MarkdownSegment[] = blocks[0].segments;
      expect(segs.length).assertEqual(3);
      expect(segs[1].type).assertEqual('code');
      expect(segs[1].content).assertEqual('console.log');
    });

    // ===== 混合内容 =====
    it('mixed_content_parsed', 0, () => {
      const md: string = '# 概述\n\n- 第一项\n- 第二项\n\n```\ncode\n```\n\n普通段落';
      const blocks: MarkdownBlock[] = MarkdownParser.parse(md);
      // heading + 2 listItems + codeBlock + paragraph = 5
      expect(blocks.length).assertEqual(5);
      expect(blocks[0].type).assertEqual('heading');
      expect(blocks[1].type).assertEqual('listItem');
      expect(blocks[2].type).assertEqual('listItem');
      expect(blocks[3].type).assertEqual('codeBlock');
      expect(blocks[4].type).assertEqual('paragraph');
    });

    // ===== 多个空行不产生多余块 =====
    it('multiple_blank_lines_ignored', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('段落一\n\n\n\n段落二');
      expect(blocks.length).assertEqual(2);
      expect(blocks[0].type).assertEqual('paragraph');
      expect(blocks[1].type).assertEqual('paragraph');
    });

    // ===== 粗斜体 =====
    it('bold_italic_inline_parsed', 0, () => {
      const blocks: MarkdownBlock[] = MarkdownParser.parse('***粗斜体***');
      expect(blocks.length).assertEqual(1);
      const segs: MarkdownSegment[] = blocks[0].segments;
      expect(segs[0].type).assertEqual('boldItalic');
      expect(segs[0].content).assertEqual('粗斜体');
    });
  });
}
