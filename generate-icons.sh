#!/bin/zsh
# Generate icon candidates for Eyes app using Hugging Face Inference (free, no credit card)
#
# Setup (one time):
#   1. Sign up free at https://huggingface.co/join (no credit card)
#   2. Create a token at https://huggingface.co/settings/tokens/new?tokenType=fineGrained
#      (enable "Make calls to Inference Providers")
#   3. Export it:  export HF_TOKEN="hf_..."
#
# Usage: ./generate-icons.sh

set -e

if [ -z "$HF_TOKEN" ]; then
  echo "Error: HF_TOKEN not set"
  echo ""
  echo "1. Sign up free at https://huggingface.co/join (no credit card)"
  echo "2. Create token at https://huggingface.co/settings/tokens/new?tokenType=fineGrained"
  echo "   (enable 'Make calls to Inference Providers')"
  echo "3. Run: export HF_TOKEN=\"hf_...\""
  exit 1
fi

OUTDIR="generated-icons"
mkdir -p "$OUTDIR"

STYLE="Ghibli-inspired, clean digital illustration, bold shapes, smooth gradients, vibrant colors, macOS app icon, rounded square, no text, centered, crisp edges, 1024x1024"
MODEL="stabilityai/stable-diffusion-xl-base-1.0"
API_URL="https://router.huggingface.co/hf-inference/models/$MODEL"

NAMES=(
  peepers
  blinky
  dreamy
  kodama
  sootie
  lantern
)

typeset -A PROMPTS
PROMPTS[peepers]="A round fluffy forest spirit character with huge sparkling eyes, bright green and white, solid color background, graphic icon design, $STYLE"
PROMPTS[blinky]="A cute soot sprite with one big eye open and one winking, solid black circle character, warm amber solid background, simple graphic, $STYLE"
PROMPTS[dreamy]="A small round sleeping spirit character with closed happy eyes, soft pastel blue solid background, simple shapes, graphic design, $STYLE"
PROMPTS[kodama]="A white glowing kodama tree spirit with big curious dot eyes, deep forest green solid background, simple flat graphic, $STYLE"
PROMPTS[sootie]="Two round soot ball characters with big glossy eyes, simple shapes on warm orange solid background, bold graphic design, $STYLE"
PROMPTS[lantern]="A friendly eye-shaped character glowing like a lantern, pink and indigo solid gradient background, bold flat graphic design, $STYLE"

echo "Generating ${#NAMES[@]} icon candidates via Hugging Face ($MODEL)..."
echo "Output: $OUTDIR/"
echo ""

for name in "${NAMES[@]}"; do
  prompt="${PROMPTS[$name]}"
  outfile="$OUTDIR/${name}.jpg"

  echo "-> $name"

  # HF inference returns raw image bytes directly
  http_code=$(curl -sL -w "%{http_code}" -o "$outfile" "$API_URL" \
    -H "Authorization: Bearer $HF_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"inputs\": \"$prompt\",
      \"parameters\": {
        \"width\": 1024,
        \"height\": 1024
      }
    }")

  if [ "$http_code" != "200" ]; then
    echo "   FAILED (HTTP $http_code):"
    head -c 300 "$outfile"
    echo ""
    rm -f "$outfile"
    sleep 5
    continue
  fi

  filetype=$(file -b "$outfile")
  if echo "$filetype" | grep -qi "image"; then
    size=$(wc -c < "$outfile" | tr -d ' ')
    echo "   saved: $outfile ($size bytes) - $filetype"
  else
    echo "   FAILED: response is not an image ($filetype)"
    head -c 300 "$outfile"
    echo ""
    rm -f "$outfile"
  fi

  sleep 5
done

echo ""
echo "Done! Check $OUTDIR/ for your icon candidates."
echo "Pick your favorite, then resize for macOS icon set (16/32/128/256/512/1024)."
