import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppI18n {
  AppI18n(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppI18n> delegate = _AppI18nDelegate();

  static const List<Locale> supportedLocales = [
    Locale('zh'),
    Locale('en'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppI18n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppI18n of(BuildContext context) {
    final value = Localizations.of<AppI18n>(context, AppI18n);
    assert(value != null, 'AppI18n not found in context');
    return value!;
  }

  bool get _isEnglish => locale.languageCode.toLowerCase().startsWith('en');

  String t(String zh, {Map<String, Object?> args = const {}}) {
    var value = _isEnglish ? (_en[zh] ?? zh) : zh;
    for (final entry in args.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return value;
  }

  static const Map<String, String> _en = {
    '设置': 'Settings',
    '语言': 'Language',
    '选择应用显示语言': 'Choose app display language',
    '在主页显示余额': 'Show Balance on Home',
    '在主页输入框上方显示账户余额': 'Show account balance above the prompt box on home',
    '保存提示框位置': 'Save Toast Position',
    '保存图片后的提示框显示在顶部或底部': 'Show save-image toast at top or bottom',
    '底部': 'Bottom',
    '顶部': 'Top',
    'API 配置': 'API Configuration',
    'API 端点': 'API Endpoint',
    '输入你的 API Key': 'Enter your API Key',
    '测试中...': 'Testing...',
    '测试连通性': 'Test Connectivity',
    '查看结果': 'View Result',
    '模型': 'Model',
    '图片比例': 'Aspect Ratio',
    '图片尺寸': 'Image Size',
    '启用自动重试': 'Enable Auto Retry',
    '请求超时（秒）': 'Request Timeout (sec)',
    '最大自动重试次数': 'Max Auto Retry Count',
    '参考图兼容性增强': 'Reference Compatibility Mode',
    '参考图上传模式': 'Reference Upload Mode',
    '添加时预压缩参考图': 'Pre-compress on Add',
    '参考图预览大小': 'Reference Preview Size',
    '单张参考图上限': 'Single Reference Image Limit',
    '参考图预处理': 'Reference Preprocess',
    '参考图格式': 'Reference Format',
    '参考图最大边长': 'Reference Max Dimension',
    '参考图质量': 'Reference Quality',
    '重试时自动降级': 'Auto Degrade on Retry',
    '发送幂等键': 'Send Idempotency Key',
    '强制 HTTPS': 'Force HTTPS',
    '图片缓存': 'Image Cache',
    '日志占用': 'Log Usage',
    '刷新': 'Refresh',
    '导出日志': 'Export Logs',
    '分享日志': 'Share Logs',
    '另存为': 'Save As',
    '清空日志': 'Clear Logs',
    '清理图片缓存': 'Clear Image Cache',
    '创建备份': 'Create Backup',
    '恢复备份': 'Restore Backup',
    '账户余额': 'Account Balance',
    '点击刷新查询余额': 'Tap refresh to query balance',
    '跟随系统': 'Follow System',
    '简体中文': 'Simplified Chinese',
    '小': 'Small',
    '中': 'Medium',
    '大': 'Large',
    '自动（推荐）': 'Auto (Recommended)',
    '列表载荷（image[]）': 'List Payload (image[])',
    '单项载荷（image）': 'Single Payload (image)',
    '内置相册': 'Built-in Gallery',
    '系统相册': 'System Gallery',
    '文件选择': 'File Picker',
    '其他应用': 'Other Apps',
    '新对话': 'New Chat',
    '新建对话': 'New Chat',
    '对话历史': 'Chat History',
    '提示词已复制': 'Prompt copied',
    '错误信息已复制': 'Error copied',
    '跳转到最新消息': 'Jump to latest',
    '未选择模型': 'No model selected',
    '自动比例': 'Auto Ratio',
    '自动比例（模型决定）': 'Auto Ratio (model decides)',
    '图片过大，已自动压缩后添加': 'Image too large, auto-compressed and added',
    '请输入提示词': 'Please enter a prompt',
    '请先配置 API': 'Please configure API first',
    '任务加入队列失败，请重试': 'Failed to enqueue task, please retry',
    '未找到可保存的图片数据': 'No image data available to save',
    '已保存到相册': 'Saved to gallery',
    '保存失败: {error}': 'Save failed: {error}',
    '已加入重试队列': 'Added to retry queue',
    '重试加入队列失败，请重试': 'Failed to enqueue retry task, please retry',
    '选择模型': 'Select Model',
    '选择比例': 'Select Aspect Ratio',
    '选择分辨率': 'Select Resolution',
    '编辑队列提示词': 'Edit Queue Prompt',
    '输入新的提示词': 'Enter new prompt',
    '取消': 'Cancel',
    '保存': 'Save',
    '这条记录没有参考图': 'No reference images in this message',
    '已加入 {count} 张参考图': 'Added {count} reference image(s)',
    '复用失败：参考图文件可能已丢失': 'Reuse failed: reference image file may be missing',
    '无法读取可复用的图片数据': 'Unable to read reusable image data',
    '已将生成图加入参考图': 'Generated image added to references',
    '重命名': 'Rename',
    '输入新名称': 'Enter new name',
    '删除会话': 'Delete Session',
    '删除后不可恢复，确认删除该会话吗？': 'This cannot be undone. Delete this session?',
    '删除': 'Delete',
    '复制提示词': 'Copy Prompt',
    '保存图片': 'Save Image',
    '重试': 'Retry',
    '复用参考图': 'Reuse References',
    '复用生成图': 'Reuse Generated Image',
    '复制错误': 'Copy Error',
    '输入提示词...': 'Enter prompt...',
    '参考图': 'Refs',
    '清空': 'Clear',
    '队列': 'Queue',
    '等待中': 'Pending',
    '执行中': 'Running',
    '生成中，可继续提交': 'Generating, you can continue to enqueue',
    '正在生成中，可继续提交任务进入队列':
        'Generating, you can continue to submit tasks to queue',
    '待处理': 'Pending',
    '收起队列': 'Collapse Queue',
    '展开队列': 'Expand Queue',
    '取消当前任务': 'Cancel current task',
    '移出队列': 'Remove from queue',
    '清空队列': 'Clear Queue',
    '置顶（下一位执行）': 'Move to front (next to run)',
    '上移': 'Move up',
    '下移': 'Move down',
    '重试任务': 'Retry Task',
    '编辑提示词': 'Edit Prompt',
    '生成失败': 'Generation failed',
    '刚刚': 'Just now',
    '{count} 分钟前': '{count} min ago',
    '{count} 小时前': '{count} h ago',
    '{count} 天前': '{count} d ago',
    '{count} 张': '{count}',
    '读取原图失败，请重试': 'Failed to read original image, please retry',
    '选择图片': 'Select Image',
    '打开权限设置': 'Open Permission Settings',
    '没有图片': 'No images',
    '相册集': 'Albums',
    '需要相册访问权限': 'Gallery permission is required',
    '未找到图片': 'No images found',
    '加载失败: {error}': 'Load failed: {error}',
    '加载相册失败: {error}': 'Failed to load album: {error}',
  };
}

class _AppI18nDelegate extends LocalizationsDelegate<AppI18n> {
  const _AppI18nDelegate();

  @override
  bool isSupported(Locale locale) => AppI18n.supportedLocales
      .any((e) => e.languageCode == locale.languageCode);

  @override
  Future<AppI18n> load(Locale locale) =>
      SynchronousFuture<AppI18n>(AppI18n(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppI18n> old) => false;
}

extension AppI18nBuildContextExt on BuildContext {
  String tr(String zh, {Map<String, Object?> args = const {}}) =>
      AppI18n.of(this).t(zh, args: args);
}
