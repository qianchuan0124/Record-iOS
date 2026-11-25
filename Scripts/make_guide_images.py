"""Generate the guide images used by README.md.

Usage:
    GUIDE_SOURCE_DIR=docs/images/source python3 Scripts/make_guide_images.py

Input screenshots come from GUIDE_SOURCE_DIR (default docs/images/source).
Each output is one original app screenshot with a dark mask, cut-out highlights,
small speech bubbles, and the flow title drawn on top of the image itself.
Steps that happen on the same screen are all placed on that single image.

Requires Pillow:
    python3 -m pip install pillow
"""

import os
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PREVIEW = Path(os.environ.get(
    'GUIDE_SOURCE_DIR', str(REPO / 'docs' / 'images' / 'source'))).expanduser()
OUTPUT = REPO / 'docs' / 'images'

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_PATH = '/System/Library/Fonts/Hiragino Sans GB.ttc'

ACCENT = (229, 180, 95)
DIM = (8, 10, 14, 132)
BUBBLE_BG = (255, 255, 255)
BUBBLE_TEXT = (28, 33, 44)
BUBBLE_SUB = (92, 100, 114)
TITLE_TEXT = (238, 242, 247)
TITLE_SUB = (158, 168, 184)

Rect = tuple[int, int, int, int]
Callout = tuple[Rect, int, str, str]


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_PATH, size, index=0)


def wrap(text: str, ft: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines: list[str] = []
    current = ''
    for char in text:
        if ft.getlength(current + char) <= width:
            current += char
        else:
            lines.append(current)
            current = char
    if current:
        lines.append(current)
    if len(lines) > 1 and lines[-1] and lines[-1] in '。，、；：！？）':
        lines[-2] += lines[-1]
        lines.pop()
    while len(lines) > 1 and len(lines[-1]) < 4 and len(lines[-2]) > 6:
        lines[-1] = lines[-2][-1] + lines[-1]
        lines[-2] = lines[-2][:-1]
    return lines


def load_preview(name: str, redactions: tuple[Rect, ...] = ()) -> Image.Image:
    img = Image.open(PREVIEW / name).convert('RGB')
    for rect in redactions:
        img.paste(img.crop(rect).filter(ImageFilter.GaussianBlur(9)), rect)
    return img


def overlaps(a: Rect, b: Rect, margin: int = 0) -> bool:
    return not (a[2] + margin <= b[0] or b[2] + margin <= a[0]
                or a[3] + margin <= b[1] or b[3] + margin <= a[1])


def draw_tail(draw, side: str, bx: int, by: int, bw: int, bh: int,
              cx: int, cy: int) -> None:
    size = 11
    if side == 'below':
        tx = min(max(cx, bx + 18), bx + bw - 18)
        draw.polygon([(tx - 9, by), (tx + 9, by), (tx, by - size)], fill=BUBBLE_BG)
    elif side == 'above':
        tx = min(max(cx, bx + 18), bx + bw - 18)
        draw.polygon([(tx - 9, by + bh), (tx + 9, by + bh), (tx, by + bh + size)],
                     fill=BUBBLE_BG)
    elif side == 'right':
        ty = min(max(cy, by + 18), by + bh - 18)
        draw.polygon([(bx, ty - 9), (bx, ty + 9), (bx - size, ty)], fill=BUBBLE_BG)
    else:
        ty = min(max(cy, by + 18), by + bh - 18)
        draw.polygon([(bx + bw, ty - 9), (bx + bw, ty + 9), (bx + bw + size, ty)],
                     fill=BUBBLE_BG)


def place_bubble(width: int, height: int, bw: int, bh: int, hole: Rect,
                 obstacles: list[Rect], placed: list[Rect],
                 gap: int = 20, prefer: str = '') -> tuple[str, int, int]:
    cx = (hole[0] + hole[2]) // 2
    cy = (hole[1] + hole[3]) // 2
    candidates = [
        ('below', cx - bw // 2, hole[3] + gap),
        ('above', cx - bw // 2, hole[1] - gap - bh),
        ('right', hole[2] + gap, cy - bh // 2),
        ('left', hole[0] - gap - bw, cy - bh // 2),
    ]
    if prefer:
        candidates.sort(key=lambda item: item[0] != prefer)
    fallback = None
    for side, raw_x, raw_y in candidates:
        x = min(max(raw_x, 20), width - bw - 20)
        y = min(max(raw_y, 20), height - bh - 20)
        box = (x, y, x + bw, y + bh)
        if fallback is None:
            fallback = (side, x, y)
        if any(overlaps(box, other, 10) for other in obstacles):
            continue
        if any(overlaps(box, other, 12) for other in placed):
            continue
        return side, x, y
    return fallback


TITLE_W, TITLE_H = 340, 84


def title_box(width: int, height: int, scale: float = 1.0) -> Rect:
    panel_w = round(TITLE_W * scale)
    panel_h = round(TITLE_H * scale)
    return width - 20 - panel_w, height - 20 - panel_h, width - 20, height - 20


def annotate(img: Image.Image, callouts: list[Callout], total: int,
             title: str, subtitle: str, bubble_scale: float = 1.0,
             title_scale: float = 1.0) -> Image.Image:
    img = img.copy().convert('RGB')
    width, height = img.size
    pad = 7

    def pad_box(rect):
        return (max(0, rect[0] - pad), max(0, rect[1] - pad),
                min(width - 1, rect[2] + pad), min(height - 1, rect[3] + pad))

    def to_rects(value):
        if isinstance(value, tuple) and len(value) == 4 and isinstance(value[0], int):
            return [value]
        return list(value)

    groups = []
    all_boxes = []
    for callout in callouts:
        raw = to_rects(callout[0])
        boxes = [pad_box(rect) for rect in raw]
        groups.append((raw, boxes, callout))
        all_boxes.extend(boxes)

    dim = Image.new('RGBA', img.size, DIM)
    hole_mask = Image.new('L', img.size, DIM[3])
    hole_draw = ImageDraw.Draw(hole_mask)
    for box in all_boxes:
        hole_draw.rounded_rectangle(box, radius=13, fill=0)
    dim.putalpha(hole_mask)
    base = Image.alpha_composite(img.convert('RGBA'), dim)

    glow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for box in all_boxes:
        glow_draw.rounded_rectangle(box, radius=13, outline=ACCENT + (165,), width=8)
    base = Image.alpha_composite(base, glow.filter(ImageFilter.GaussianBlur(10)))
    img = base.convert('RGB')
    draw = ImageDraw.Draw(img)
    for box in all_boxes:
        draw.rounded_rectangle(box, radius=13, outline=ACCENT, width=3)

    panel = title_box(width, height, scale=title_scale)
    panel_w = panel[2] - panel[0]
    title_inset = round(14 * title_scale)
    title_top = round(14 * title_scale)
    text_x = panel[0] + round(30 * title_scale)
    draw.rounded_rectangle(panel, radius=round(14 * title_scale), fill=(8, 10, 14, 140))
    draw.rectangle((panel[0] + title_inset, panel[1] + round(16 * title_scale),
                    panel[0] + title_inset + round(4 * title_scale),
                    panel[3] - round(16 * title_scale)), fill=ACCENT)
    title_ft = font(round(24 * title_scale))
    sub_ft = font(round(13 * title_scale))
    draw.text((text_x, panel[1] + title_top), title, font=title_ft, fill=TITLE_TEXT)
    sub_lines = wrap(subtitle, sub_ft, panel_w - round(44 * title_scale))[:2]
    for index, line in enumerate(sub_lines):
        draw.text((text_x, panel[1] + round(50 * title_scale) + index * round(17 * title_scale)),
                  line, font=sub_ft, fill=TITLE_SUB)
    obstacles = all_boxes + [panel]

    title_ft = font(round(19 * bubble_scale))
    body_ft = font(round(16 * bubble_scale))
    step_ft = font(round(11 * bubble_scale))
    bw = round(290 * bubble_scale)
    line_height = round(23 * bubble_scale)
    text_width = bw - 34
    placed: list[Rect] = []

    for raw, boxes, callout in groups:
        step, step_title, body = callout[1:4]
        prefer = callout[4] if len(callout) > 4 else ''
        lines = wrap(body, body_ft, text_width)
        bh = 14 + 24 + 6 + len(lines) * line_height + 13
        anchor = boxes[0]
        manual = callout[5] if len(callout) > 5 else None
        if manual:
            bx, by = manual
            if bx + bw <= raw[0][0]:
                side = 'left'
            elif bx >= raw[0][2]:
                side = 'right'
            elif by + bh <= raw[0][1]:
                side = 'above'
            else:
                side = 'below'
        else:
            side, bx, by = place_bubble(width, height, bw, bh, raw[0], obstacles, placed,
                                        prefer=prefer)
        placed.append((bx, by, bx + bw, by + bh))

        cx = (anchor[0] + anchor[2]) // 2
        cy = (anchor[1] + anchor[3]) // 2

        shadow = Image.new('RGBA', img.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            (bx, by + 5, bx + bw, by + bh + 6), radius=16, fill=(0, 0, 0, 145))
        img = Image.alpha_composite(img.convert('RGBA'),
                                    shadow.filter(ImageFilter.GaussianBlur(12))).convert('RGB')
        draw = ImageDraw.Draw(img)
        draw.rounded_rectangle((bx, by, bx + bw, by + bh), radius=16,
                               fill=BUBBLE_BG, outline=(228, 232, 238), width=1)
        draw_tail(draw, side, bx, by, bw, bh, cx, cy)

        badge = f'{step}/{total}'
        badge_w = step_ft.getlength(badge) + 18
        draw.rounded_rectangle((bx + 16, by + 15, bx + 16 + badge_w, by + 39),
                               radius=12, fill=ACCENT)
        draw.text((bx + 16 + badge_w / 2, by + 26), badge, font=step_ft,
                  fill=(33, 27, 16), anchor='mm')
        draw.text((bx + 28 + badge_w, by + 17), step_title, font=title_ft, fill=BUBBLE_TEXT)

        y = by + 48
        for line in lines:
            draw.text((bx + 17, y), line, font=body_ft, fill=BUBBLE_SUB)
            y += line_height

    return img


def main() -> None:
    def load(name: str) -> Image.Image:
        return load_preview(name)

    jobs = [
        ('guide-ledger.png', load('ledger.png'), 3, '账单与筛选',
         '月度汇总、按天分组和搜索筛选都在一个页面完成', [
             ((45, 350, 1160, 560), 1, '月度汇总',
              '顶部固定显示支出、收入和结余，月份、搜索与筛选入口都在这里。', 'below', (545, 195)),
             ((930, 225, 1160, 315), 2, '搜索与筛选',
              '搜索按分类、子分类或备注匹配；筛选可组合分类、金额与时间。', 'right', (870, 80)),
             ((45, 600, 1160, 1230), 3, '按天查看',
              '账单按日期分组，点任意一条查看详情或编辑。', 'below'),
         ]),
        ('guide-analysis.png', load('analysis.png'), 3, '分析与下钻',
         '全部时间 / 单月、分类占比与年度切换', [
             ((400, 480, 800, 590), 1, '全部时间 / 单月',
              '默认展示全部时间，也可以切换到任意月份。', 'left', (60, 500)),
             ((300, 620, 880, 1180), 2, '分类占比',
              '环形图按支出分类汇总，金额较大时中心数字自动缩放。', 'right', (885, 700)),
             ((45, 1300, 1160, 2300), 3, '分类下钻',
              '点击分类进入明细，可切换按时间或按金额排序。', 'below'),
         ]),
        ('guide-assets.png', load('assets.png'), 3, '资产与预算',
         '预算、工资、存款三段切换，集中管理资产与负债', [
             ((45, 350, 1160, 450), 1, '三段切换',
              '预算 / 工资 / 存款，默认进入预算。', 'below'),
             ((45, 475, 1160, 960), 2, '月度预算',
              '显示超支、总预算和已花金额，进度条直观展示消耗。', 'below'),
             ((45, 1495, 1160, 1980), 3, '预算项',
              '按分类维护预算金额，点击可编辑。', 'above'),
         ]),
        ('guide-filter.png', load('filter.png'), 1, '筛选', 
         '按类型、分类、金额和时间范围组合筛选', [
             ((45, 960, 1160, 2420), 1, '组合筛选',
              '类型、分类、金额和时间范围可以组合，底部实时显示匹配笔数。', 'above'),
         ]),
        ('guide-editor.png', load('editor.png'), 1, '新增账单',
         '一屏完成金额、分类、日期和备注', [
             ((45, 960, 1160, 2280), 1, '记一笔',
              '选择收支类型与分类，填写金额和备注后保存；计入预算会自动参与预算统计。', 'above'),
         ]),
        ('guide-yearly.png', load('yearly.png'), 3, '年度',
         '结余、近五年收支、支出月历与分类汇总', [
             ((45, 500, 1160, 780), 1, '结余与年份',
              '年份菜单在结余卡片右侧，切换年份后整页同步更新。', 'below'),
             ((45, 850, 1160, 1250), 2, '5 年收支对比',
              '柱状图对比近五年收入与支出，当前年份高亮。', 'below'),
             ((45, 1280, 1160, 1858), 3, '支出月历',
              '按月汇总全年支出，点月份可回到对应月份概览。', 'above'),
         ]),
        ('guide-timeline.png', load('timeline.png'), 2, '时间线',
         '把全年关键节点按时间串起来', [
             ((45, 500, 1160, 700), 1, '年度摘要',
              '展示当年账单数、总支出和总收入。', 'below'),
             ((45, 750, 1160, 1740), 2, '关键事件',
              '最后一笔、大额支出、最大收支等事件按时间排序，点击可查看详情。', 'above'),
         ]),
        ('guide-salary.png', load('salary-assets.png'), 2, '工资',
         '税前、税后、个税和工资记录集中展示', [
             ((45, 350, 1160, 650), 1, '工资汇总',
              '顶部展示税前、税和税后合计，年份菜单可筛选全部年份。', 'below'),
             ((45, 700, 1160, 1250), 2, '工资记录',
              '每笔记录显示发薪日、基本工资、加班费和个税。', 'below'),
         ]),
        ('guide-salary-editor.png', load('salary-editor.png'), 2, '新增工资',
         '累计预扣、算税月份和实际到手', [
             ((45, 420, 1160, 1140), 1, '工资输入',
              '基本工资、加班费、一次性奖金和五险一金；可参考上月自动填充。', 'below'),
             ((45, 1170, 1160, 2100), 2, '算税与到手',
              '选择本月/上月归属，收起键盘或点完成后更新税前、税率、税额和实际到手。', 'below'),
         ]),
        ('guide-deposit.png', load('deposit.png'), 2, '存款',
         '银行、金额、利率、期限和利息集中管理', [
             ((45, 350, 1160, 700), 1, '存款汇总',
              '显示银行数、存款笔数、总金额和总利息。', 'below'),
             ((45, 780, 1160, 1700), 2, '存款列表',
              '每笔存款展示银行、期限、利率和利息，支持排序、更新和删除。', 'above'),
         ]),
        ('guide-deposit-editor.png', load('deposit-editor.png'), 2, '新增存款',
         '选择银行后自动计算到期时间与利息', [
             ((45, 420, 1160, 1340), 1, '选择银行',
              '按名称搜索银行，点击选择；支持内置银行和手动添加的银行。', 'above'),
             ((45, 1380, 1160, 2200), 2, '存款信息',
              '根据存款信息填写金额、时间、年限和利率，自动计算利息与到期时间。', 'above'),
         ]),
        ('guide-settings.png', load('settings.png'), 2, '设置',
         '数据处理、同步、外观和自定义分类', [
             ((45, 340, 1160, 720), 1, '数据',
              '数据处理负责导入导出，iCloud 同步管理备份文件夹。', 'above'),
             ((45, 800, 1160, 1170), 2, '个性化',
              '外观切换深浅色，自定义分类管理收支分类。', 'below'),
         ]),
        ('guide-sync.png', load('sync.png'), 2, '云同步',
         '文件夹快照备份与云端恢复', [
             ((45, 360, 1160, 1150), 1, '同步状态',
              '显示本机记录、云端备份数和上次备份时间。', 'below'),
             ((45, 1500, 1160, 2000), 2, '同步操作',
              '立即同步、更改同步目录或清除文件夹。', 'below'),
         ]),
        ('guide-sync-picker.png', load('sync-picker.png'), 2, '同步版本',
         '在本机数据与云端快照之间选择同步方向', [
             ((45, 420, 1160, 850), 1, '本机当前数据',
              '显示本机账单、存款、薪酬和预算数量；按钮用于把本机数据备份到云端。', 'below'),
             ((45, 940, 1160, 1220), 2, '云端备份',
              '列出云端快照的设备、时间、类型和大小，可恢复到本机。', 'above'),
         ]),
        ('guide-search.png', load('search.png'), 2, '搜索与历史',
         '按分类、子分类或备注搜索，最近关键词保存在本机', [
             ((45, 1780, 1160, 1920), 1, '搜索入口',
              '输入关键词后点搜索；最近 10 条记录会显示在空态。', 'above'),
             ((45, 1960, 1160, 2300), 2, '结果高亮',
              '匹配到的文字会高亮，点结果进入详情。', 'below'),
         ]),
    ]

    OUTPUT.mkdir(parents=True, exist_ok=True)
    for stale in OUTPUT.glob('guide-*.png'):
        stale.unlink()

    for name, img, total, title, subtitle, callouts in jobs:
        result = annotate(
            img, callouts, total, title, subtitle,
            bubble_scale=1.1,
            title_scale=1.2
        )
        result.save(OUTPUT / name, optimize=True)

    print('guide images written to', OUTPUT)

if __name__ == '__main__':
    main()
