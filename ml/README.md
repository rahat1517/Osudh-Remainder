# 🧠 ml/: Local LLM fine-tuning (পরবর্তী ধাপ)

পরিকল্পনা:
1. ব্যবহারকারীর confirm করা প্রেসক্রিপশন থেকে label সংগ্রহ (অনুমতি নিয়ে, ব্যক্তিগত তথ্য মুছে)
2. ভাগ: ৮০% train / ১০% validation / ১০% test
3. Open-source vision model (যেমন Qwen2.5-VL 7B) + LoRA/QLoRA fine-tune
4. Test set-এ মাপা: ওষুধের নাম %, ডোজ %, সময় %, মেয়াদ %
5. Hybrid: local model আগে চেষ্টা করবে, confidence কম হলে cloud AI

## ⚠️ নিয়ম
- **আসল প্রেসক্রিপশন বা রোগীর তথ্য এখানে commit করা যাবে না।** `ml/data/` ফোল্ডার `.gitignore`-এ আছে
- Model ফাইল (`.safetensors`, `.gguf`) Hugging Face-এ (private) রাখুন
