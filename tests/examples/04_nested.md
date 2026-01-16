# Deeply Nested Injections Test

This file tests extraction of code at multiple nesting levels.

## First HTML Block

```html
<div id="block1">
  <p>First HTML block</p>
  <script>
    // JS in first HTML block
    const block1 = "first";
    console.log(block1);
  </script>
  <style>
    #block1 { color: red; }
  </style>
</div>
```

## Second HTML Block

```html
<div id="block2">
  <p>Second HTML block</p>
  <script>
    // JS in second HTML block
    const block2 = "second";
    console.log(block2);
  </script>
  <style>
    #block2 { color: blue; }
  </style>
</div>
```

## Standalone JavaScript Block

```javascript
// Standalone JS
const standalone = "standalone";
function doSomething() {
  return standalone;
}
```

## Third HTML Block with Multiple Scripts

```html
<div id="block3">
  <script>
    // First script in block3
    const first = 1;
  </script>
  <p>Some content between scripts</p>
  <script>
    // Second script in block3
    const second = 2;
  </script>
</div>
```

## Standalone CSS Block

```css
/* Standalone CSS */
body {
  margin: 0;
  padding: 0;
}
```
