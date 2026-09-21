# T37 Android実機確認: app内file browserの範囲選択

実装後にcurrent revisionと照合して操作・fixture・期待結果を完成させる。Android物理端末を使い、emulatorだけを受け入れ証拠にしない。

確認対象は、現在folderの全選択controlを操作名から認識してtapできること、fileだけが全選択されfolder・近道が含まれないこと、長押しdragの往復、edge auto-scroll、開始行offscreen後の停止・反転・解除、lift/cancel、folder移動時の解除である。
