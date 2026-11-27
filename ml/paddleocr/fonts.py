"""Fonts for synthetic training lines (Google Fonts, under ofl/ or apache/), shared by the Colab
notebook and the weekly training workflow."""

# Google Fonts paths (ofl/ or apache/ is tried in turn)
FONTS = {
    # Bangla
    "NotoSansBengali.ttf": "notosansbengali/NotoSansBengali%5Bwdth%2Cwght%5D.ttf",
    "NotoSerifBengali.ttf": "notoserifbengali/NotoSerifBengali%5Bwdth%2Cwght%5D.ttf",
    "HindSiliguri-Regular.ttf": "hindsiliguri/HindSiliguri-Regular.ttf",
    "HindSiliguri-Medium.ttf": "hindsiliguri/HindSiliguri-Medium.ttf",
    "HindSiliguri-Bold.ttf": "hindsiliguri/HindSiliguri-Bold.ttf",
    "AnekBangla.ttf": "anekbangla/AnekBangla%5Bwdth%2Cwght%5D.ttf",
    "BalooDa2.ttf": "balooda2/BalooDa2%5Bwght%5D.ttf",
    "Galada-Regular.ttf": "galada/Galada-Regular.ttf",
    "Mina-Regular.ttf": "mina/Mina-Regular.ttf",
    "TiroBangla-Regular.ttf": "tirobangla/TiroBangla-Regular.ttf",
    # Latin handwriting: doctors write medicine names, strengths and doses by hand
    "Caveat.ttf": "caveat/Caveat%5Bwght%5D.ttf",
    "IndieFlower.ttf": "indieflower/IndieFlower-Regular.ttf",
    "ShadowsIntoLight.ttf": "shadowsintolight/ShadowsIntoLight.ttf",
    "PatrickHand.ttf": "patrickhand/PatrickHand-Regular.ttf",
    "GochiHand.ttf": "gochihand/GochiHand-Regular.ttf",
    "ArchitectsDaughter.ttf": "architectsdaughter/ArchitectsDaughter-Regular.ttf",
    "Handlee.ttf": "handlee/Handlee-Regular.ttf",
    "NanumPen.ttf": "nanumpenscript/NanumPenScript-Regular.ttf",
    "HomemadeApple.ttf": "homemadeapple/HomemadeApple-Regular.ttf",
    "JustAnotherHand.ttf": "justanotherhand/JustAnotherHand-Regular.ttf",
    "Kalam.ttf": "kalam/Kalam-Regular.ttf",
    "Sacramento.ttf": "sacramento/Sacramento-Regular.ttf",
}
# Never trained on: the quick check reads lines in these to see how the model copes with new hands
HOLDOUT_FONTS = {
    "Atma-Regular.ttf": "atma/Atma-Regular.ttf",
    "ReenieBeanie.ttf": "reeniebeanie/ReenieBeanie.ttf",
}
