"""Build the Clockodile walk cycle sprite sheet from base.svg parts.

Run from WSL:  python3 make_walk.py
Needs ImageMagick `convert`. Writes walk/frame_XX.svg and walk/walk_sheet.png.
The motion follows the "Motion inspiration - Walk" reference: alternating
stubby legs, counter-swinging arms, body bob on each step, tail sway.
"""
import math
import pathlib
import subprocess

FRAMES = 12   # 12 frames at ~18 fps = one step pair in ~0.65 s
SIZE = 256    # px per frame in the sheet
OUT = pathlib.Path(__file__).parent / "walk"

LEG_SWING = 24   # degrees
ARM_SWING = 16
LEG_LIFT = 50    # px the swinging foot rises
BOB = 14         # px the body rises at the passing pose
TAIL_SWAY = 5
HEAD_TILT = 2.5

INK = "#003b24"

DEFS = """<defs>
  <linearGradient id="skin" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#a0dc75"/><stop offset="1" stop-color="#98d66e"/></linearGradient>
  <linearGradient id="light-skin" x1="0" y1="0" x2="0.8" y2="1"><stop stop-color="#d4f49b"/><stop offset="1" stop-color="#c7ed8d"/></linearGradient>
  <linearGradient id="belly-fill" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#fff3ac"/><stop offset="1" stop-color="#fff0a5"/></linearGradient>
  <linearGradient id="cheek-fill" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#ffc5a3"/><stop offset="1" stop-color="#ffbb9c"/></linearGradient>
</defs>"""

BACK_SPIKES = """<g fill="#327e50">
  <path d="M825 191 C884 179 936 203 955 237 C976 274 949 320 914 346 Z"/>
  <path d="M915 363 C964 373 1004 404 1009 439 C1014 475 965 522 909 548 Z"/>
  <path d="M890 574 C941 578 998 610 1010 641 C1024 679 991 721 947 753 Z"/>
</g>"""

ARM_BACK = '<path fill="url(#skin)" d="M301 612 C255 644 218 687 198 733 C175 790 194 821 244 837 L324 685 Z"/>'

TAIL = """<g fill="#327e50">
  <path d="M953 793 C1007 768 1050 775 1062 806 C1071 830 1064 864 1054 887 Z"/>
  <path d="M1056 864 C1098 850 1127 866 1119 902 L1064 908 Z"/>
</g>
<path fill="url(#skin)" d="M869 729 C927 741 934 824 974 862 C1015 899 1082 919 1147 929 C1178 933 1159 974 1137 996 C1077 1052 975 1086 877 1080 L812 990 Z"/>"""

TAIL_SPOTS = f"""<g fill="#519e48" stroke="none">
  <ellipse cx="906" cy="871" rx="22" ry="20"/>
  <ellipse cx="954" cy="910" rx="26" ry="24" transform="rotate(-35 954 910)"/>
  <ellipse cx="1024" cy="932" rx="23" ry="21" transform="rotate(-20 1024 932)"/>
</g>"""

# Legs are the feet of base.svg, drawn in front of the torso like arm-front:
# filled shape plus an outline open at the top, so the leg grows out of the body.
LEG_BACK_OUTLINE = "M306 1062 L305 1083 C264 1114 272 1139 309 1147 C351 1156 408 1160 445 1146 C467 1137 480 1107 478 1076 L477 1062"
LEG_FRONT_OUTLINE = "M662 1040 L658 1085 C665 1102 674 1117 683 1127 C657 1155 678 1167 714 1171 C756 1177 817 1177 846 1162 C874 1147 882 1110 887 1080 L884 1040"
LEG_BACK = f"""<path fill="url(#skin)" stroke="none" d="{LEG_BACK_OUTLINE} C430 1050 350 1050 306 1062 Z"/>
<path fill="none" d="{LEG_BACK_OUTLINE}"/>
<path fill="{INK}" stroke="none" d="M330 1145 C330 1103 380 1097 378 1148 Z"/>"""
LEG_FRONT = f"""<path fill="url(#skin)" stroke="none" d="{LEG_FRONT_OUTLINE} C820 1020 720 1020 662 1040 Z"/>
<path fill="none" d="{LEG_FRONT_OUTLINE}"/>
<path fill="{INK}" stroke="none" d="M733 1171 C733 1119 784 1113 784 1173 Z"/>"""
HIP_BACK = (395, 1000)
HIP_FRONT = (773, 1000)
FOOT_DEPTH = 150  # hip to sole, used to keep the planted foot on the ground

# Torso = base body without feet. One outline from shoulder round the bottom to the tail.
TORSO = f"""<path fill="url(#skin)" stroke="none" d="M303 603 C276 692 235 790 241 878 C240 959 279 1029 318 1078 C430 1112 760 1112 882 1078 C914 1005 956 914 951 839 C930 747 906 662 888 581 L791 529 L411 536 Z"/>
<path fill="none" d="M303 613 C276 692 235 790 241 878 C240 959 279 1029 318 1078 C430 1112 760 1112 882 1078"/>
<path fill="none" d="M888 581 C908 640 929 707 944 767 C953 812 968 845 988 863"/>
<g stroke="none">
  <path fill="url(#belly-fill)" d="M397 617 C337 657 305 727 290 800 C269 898 292 985 372 1027 C432 1059 517 1058 581 1027 C651 994 684 930 678 849 C673 747 623 658 554 616 Z"/>
  <g fill="none" stroke="#ffe36b" stroke-width="23">
    <path d="M320 724 C426 734 539 726 648 738"/>
    <path d="M297 842 C420 854 548 855 666 853"/>
    <path d="M324 963 C431 970 543 969 638 970"/>
  </g>
</g>"""

HEAD = f"""<path fill="url(#skin)" stroke="none" d="M303 613 C207 588 92 547 53 458 C15 384 42 283 100 229 C135 198 161 212 193 234 C233 221 270 215 308 207 C320 134 377 64 441 57 C493 47 534 74 566 121 C607 69 657 45 709 62 C775 76 814 126 829 190 C892 245 921 326 923 409 C925 472 906 544 888 581 C802 627 557 634 303 613 Z"/>
<path fill="url(#light-skin)" stroke="none" d="M57 446 C85 465 121 449 150 434 C176 444 195 476 239 443 C354 469 504 446 575 435 C631 466 661 510 648 560 C638 601 608 614 561 618 C454 626 364 619 303 613 C197 586 90 538 57 446 Z"/>
<path fill="none" d="M303 613 C207 588 92 547 53 458 C15 384 42 283 100 229 C135 198 161 212 193 234 C233 221 270 215 308 207 C320 134 377 64 441 57 C493 47 534 74 566 121 C607 69 657 45 709 62 C775 76 814 126 829 190 C892 245 921 326 923 409 C925 472 906 544 888 581"/>
<g fill="{INK}" stroke="none">
  <ellipse cx="415" cy="219" rx="43" ry="44"/>
  <ellipse cx="626" cy="240" rx="43" ry="45"/>
  <circle cx="125" cy="300" r="18"/>
  <ellipse cx="229" cy="314" rx="18" ry="19"/>
</g>
<ellipse fill="url(#cheek-fill)" stroke="none" cx="723" cy="350" rx="74" ry="67"/>
<path fill="none" d="M53 441 C83 467 117 450 143 436 C168 424 185 479 222 450 L239 443 C293 463 469 458 600 416"/>
<circle cx="600" cy="415" r="17" fill="{INK}" stroke="none"/>"""

ARM_FRONT = """<path fill="url(#skin)" stroke="none" d="M673 698 C653 744 647 794 668 832 C683 860 697 853 721 839 C749 862 767 870 792 841 C811 844 825 806 830 777 L816 681 Z"/>
<path fill="none" d="M673 698 C653 744 647 794 668 832 C683 860 697 853 721 839 C749 862 767 870 792 841 C811 844 825 806 830 777"/>"""


def rot(deg, pivot):
    return f"rotate({deg:.2f} {pivot[0]} {pivot[1]})"


def leg(body, angle, lift, hip):
    # Rotating about the hip raises the sole by depth*(1-cos); push it back down.
    drop = FOOT_DEPTH * (1 - math.cos(math.radians(angle))) - lift
    return f'<g transform="translate(0 {drop:.2f}) {rot(angle, hip)}">{body}</g>'


def frame(i):
    t = 2 * math.pi * i / FRAMES
    swing = math.cos(t)  # +1 = back leg forward (croc faces left)
    bob = -BOB * abs(math.sin(t))
    tilt = HEAD_TILT * math.cos(2 * t)
    tail = TAIL_SWAY * math.sin(t)

    body = f"""
  <g transform="translate(0 {bob:.2f})">
    <g transform="{rot(-tilt, (889, 574))}">{BACK_SPIKES}</g>
    <g transform="{rot(-ARM_SWING * swing, (301, 616))}">{ARM_BACK}</g>
    <g transform="{rot(tail, (883, 993))}">{TAIL}</g>
    {TORSO}
    <g transform="{rot(tail, (883, 993))}">{TAIL_SPOTS}</g>
  </g>
  {leg(LEG_BACK, LEG_SWING * swing, LEG_LIFT * max(0, -math.sin(t)), HIP_BACK)}
  {leg(LEG_FRONT, -LEG_SWING * swing, LEG_LIFT * max(0, math.sin(t)), HIP_FRONT)}
  <g transform="translate(0 {bob:.2f})">
    <g transform="translate(0 {bob * 0.3:.2f}) {rot(tilt, (589, 584))}">{HEAD}</g>
    <g transform="{rot(ARM_SWING * swing, (673, 699))}">{ARM_FRONT}</g>
  </g>"""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1254" height="1254" viewBox="0 0 1254 1254">
{DEFS}
<g stroke="{INK}" stroke-width="30" stroke-linecap="round" stroke-linejoin="round">{body}
</g>
</svg>
"""


def main():
    OUT.mkdir(exist_ok=True)
    pngs = []
    for i in range(FRAMES):
        svg = OUT / f"frame_{i:02d}.svg"
        svg.write_text(frame(i))
        png = OUT / f"frame_{i:02d}.png"
        subprocess.run(["convert", "-background", "none", "-density", "30", str(svg),
                        "-resize", f"{SIZE}x{SIZE}", str(png)], check=True)
        pngs.append(str(png))
    subprocess.run(["convert", "-background", "none", *pngs, "+append",
                    str(OUT / "walk_sheet.png")], check=True)
    for p in pngs:
        pathlib.Path(p).unlink()
    print(f"{FRAMES} frames, {SIZE}px each -> {OUT / 'walk_sheet.png'}")


if __name__ == "__main__":
    main()
