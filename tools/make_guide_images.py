from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / 'prototype' / 'shots'
OUT = ROOT / 'docs' / 'images'
FONT_PATH = '/System/Library/Fonts/Hiragino Sans GB.ttc'

PHONE_W = 820
PHONE_H = 1728
PAD = 14
COLS = (92, 940, 1788)
ROWS = {
    'bill': (131, 2149),
    'analysis': (131, 2149),
    'payroll': (131, 2149),
    'deposit': (131,),
    'settings': (131, 2149),
}

BG_TOP = (250, 249, 253)
BG_BOTTOM = (235, 234, 243)
TEXT = (27, 31, 39)
TEXT2 = (90, 98, 116)
MUTED = (138, 144, 160)
PURPLE = (108, 93, 211)
PURPLE_BRIGHT = (138, 123, 255)
CARD = (255, 255, 255)
BORDER = (227, 229, 234)

JOBS = [
    ('guide-ledger.png', '账单 · 一屏回看', '月度汇总、按天分组、搜索与组合筛选都在一个页面完成。', [
        ('bill', 0, 0, '账单首页'),
        ('bill', 0, 1, '月份选择'),
        ('bill', 1, 2, '组合筛选'),
    ]),
    ('guide-editor.png', '记一笔 · 一屏完成', '金额、类型、分类、日期和备注一次填完，保存后回到原列表。', [
        ('bill', 0, 2, '记一笔'),
        ('bill', 1, 0, '选择分类'),
        ('bill', 1, 1, '账单详情'),
    ]),
    ('guide-analysis.png', '分析 · 从占比到下钻', '全部时间或单月概览，环形图看占比，分类明细继续下钻。', [
        ('analysis', 0, 0, '概览'),
        ('analysis', 0, 1, '分类下钻'),
    ]),
    ('guide-yearly.png', '年度 · 时间与结构', '结余、近五年收支、支出月历与分类汇总；时间线串起全年事件。', [
        ('analysis', 0, 2, '年度总览'),
        ('analysis', 1, 0, '时间线'),
    ]),
    ('guide-assets.png', '资产 · 预算与工资', '预算、工资、存款三段切换；工资详情按当前税率表自动算税。', [
        ('payroll', 0, 0, '预算'),
        ('payroll', 0, 1, '工资'),
        ('payroll', 0, 2, '工资详情'),
    ]),
    ('guide-deposit.png', '存款 · 银行与利息', '银行管理、存款记录和新增存款；利息与到期时间自动计算。', [
        ('deposit', 0, 0, '存款'),
        ('deposit', 0, 1, '新增存款'),
        ('deposit', 0, 2, '银行管理'),
    ]),
    ('guide-settings.png', '设置 · 数据与分类', '数据处理、外观、自定义分类和反馈入口集中管理。', [
        ('settings', 0, 0, '设置'),
        ('settings', 1, 0, '自定义分类'),
        ('settings', 1, 2, '数据处理'),
    ]),
    ('guide-sync.png', '同步 · 版本与恢复', '选择同步目录与版本；恢复前先写本机备份，不会静默覆盖。', [
        ('settings', 0, 1, 'iCloud 同步'),
        ('settings', 0, 2, '版本选择'),
    ]),
]


def font(size):
    return ImageFont.truetype(FONT_PATH, size, index=0)


def background(width, height):
    image = Image.new('RGB', (width, height), BG_BOTTOM)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        t = y / max(1, height - 1)
        color = tuple(round(BG_TOP[i] * (1 - t) + BG_BOTTOM[i] * t) for i in range(3))
        draw.line((0, y, width, y), fill=color)
    return image


def phone(group, row, col):
    image = Image.open(SHOTS / f'{group}.png').convert('RGB')
    left = COLS[col] - PAD
    top = ROWS[group][row] - PAD
    box = (left, top, left + PHONE_W + PAD * 2, top + PHONE_H + PAD * 2)
    return image.crop(box)


def build(job):
    filename, title, subtitle, screens = job
    count = len(screens)
    gap = 64
    margin = 82
    header_h = 234
    footer_h = 110
    phone_h = PHONE_H + PAD * 2
    width = margin * 2 + count * (PHONE_W + PAD * 2) + (count - 1) * gap
    height = header_h + phone_h + footer_h
    image = background(width, height)
    draw = ImageDraw.Draw(image)

    draw.rectangle((margin, 34, margin + 44, 40), fill=PURPLE_BRIGHT)
    draw.text((margin, 58), '记账清单 · iOS', font=font(24), fill=PURPLE)
    draw.text((margin, 96), title, font=font(54), fill=TEXT)
    draw.text((margin, 168), subtitle, font=font(25), fill=TEXT2)

    number = JOBS.index(job) + 1
    label = f'{number:02d} / {len(JOBS):02d}'
    label_font = font(22)
    draw.text((width - margin - label_font.getlength(label), 62), label,
              font=label_font, fill=MUTED)

    x = margin
    for index, (group, row, col, _) in enumerate(screens):
        tile = phone(group, row, col).convert('RGBA')
        mask = Image.new('L', tile.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, tile.width, tile.height), radius=46, fill=255)
        shadow = Image.new('RGBA', image.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            (x + 8, header_h + 12, x + tile.width + 8, header_h + tile.height + 12),
            radius=46, fill=(28, 22, 52, 88))
        image = Image.alpha_composite(image.convert('RGBA'),
                                      shadow.filter(ImageFilter.GaussianBlur(18))).convert('RGB')
        image.paste(tile, (x, header_h), mask)
        caption = screens[index][3]
        badge_x = x + PHONE_W // 2 - 96
        badge_y = header_h + phone_h + 20
        draw = ImageDraw.Draw(image)
        draw.ellipse((badge_x, badge_y, badge_x + 34, badge_y + 34), fill=PURPLE_BRIGHT)
        badge_font = font(19)
        draw.text((badge_x + 17, badge_y + 17), str(index + 1), font=badge_font,
                  fill=(255, 255, 255), anchor='mm')
        draw.text((badge_x + 46, badge_y + 8), caption, font=font(24), fill=TEXT2)
        x += PHONE_W + PAD * 2 + gap

    OUT.mkdir(parents=True, exist_ok=True)
    scale = 1800 / width
    image = image.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)
    image.save(OUT / filename, optimize=True)
    print('wrote', OUT / filename)


def main():
    for job in JOBS:
        build(job)


if __name__ == '__main__':
    main()
