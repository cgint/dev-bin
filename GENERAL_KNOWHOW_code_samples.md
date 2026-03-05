# Code Samples

## DSPy

[https://dspy.ai/cheatsheet/](https://dspy.ai/cheatsheet/)

### Minimal setup to run with LM usage statistics

```python
import dspy

# Configure DSPy with LM and usage tracking enabled, ...
gemini_non_thinking=dspy.LM('vertex_ai/gemini-2.5-flash', reasoning_effort="disable", temperature=0.3, max_tokens=16000, cache=False)
# gemini_thinking = dspy.LM('vertex_ai/gemini-2.5-flash', thinking={"type": "enabled", "budget_tokens": 128})
dspy.settings.configure(lm=gemini_non_thinking, track_usage=True)
dspy.configure_cache(enable_disk_cache=False, enable_memory_cache=False)

# Define a simple DSPy module that calls the LM twice
class MyProgram(dspy.Module):
[...]

# Instantiate and run the program
program = MyProgram()
output = program(question="What is the capital of France?")

# Get LM usage statistics
print(output.get_lm_usage())

# This will print the history - it does not return anything
dspy.inspect_history()
```
