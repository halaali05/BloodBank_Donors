import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

class DonorProfileDonationRestrictionsPage extends StatelessWidget {
  const DonorProfileDonationRestrictionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Donation restrictions',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: const [
            _HeaderSection(),
            SizedBox(height: 10),
            _ExpandableInfoCard(
              title: 'أهمية التبرع بالدم',
              icon: Icons.favorite_rounded,
              content:
                  'أخي المتبرع/أختي المتبرعة\n'
                  'إن التبرع بالدم عمل إنساني نبيل لأنه يساهم في إنقاذ حياة المرضى وممن هم في أمس الحاجة لنقل الدم إليهم.\n'
                  'الإنسان هو المنتج الوحيد للدم ولا يمكن تصنيعه، فإن حاجة المريض لتبرعك بالدم في غاية الأهمية للحفاظ على حياته بإذن الله.',
            ),
            _ExpandableInfoCard(
              title: 'هل تعلم؟',
              icon: Icons.lightbulb_rounded,
              content:
                  'الدم سائل أحمر اللون يتحرك داخل الأوعية الدموية بالجسم، ويمثل حوالي 8% من وزن الجسم.\n'
                  'تتراوح كمية الدم في الإنسان البالغ بين 5-6 لترات، وتختلف حسب الحجم والعمر.',
            ),
            _ExpandableInfoCard(
              title: 'مكونات الدم',
              icon: Icons.science_rounded,
              content:
                  'يتكون الدم من بلازما وخلايا.\n'
                  'أما البلازما فهي الجزء السائل الذي يحمل المواد الغذائية والهرمونات.\n'
                  'وأما الخلايا فتتكون من:\n'
                  '• خلايا الدم الحمراء\n'
                  '• خلايا الدم البيضاء\n'
                  '• الصفائح الدموية',
            ),
            _ExpandableInfoCard(
              title: 'خلايا الدم الحمراء',
              icon: Icons.bloodtype_rounded,
              content:
                  'تحمل خلايا الدم الحمراء الأكسجين من الرئة إلى جميع أنسجة الجسم، وتعيد ثاني أكسيد الكربون إلى الرئتين للتخلص منه.',
            ),
            _ExpandableInfoCard(
              title: 'خلايا الدم البيضاء',
              icon: Icons.shield_rounded,
              content:
                  'تساعد خلايا الدم البيضاء الجهاز المناعي في الجسم على مقاومة الالتهابات والأمراض.',
            ),
            _ExpandableInfoCard(
              title: 'الصفائح الدموية',
              icon: Icons.grain_rounded,
              content:
                  'الصفائح الدموية تساعد في تكوين الجلطة وإيقاف النزيف عند حدوث الجروح.',
            ),
            _ExpandableInfoCard(
              title: 'الهيموجلوبين',
              icon: Icons.biotech_rounded,
              content:
                  'الهيموجلوبين (اليحمور) مادة موجودة داخل خلايا الدم الحمراء، ومسؤولة عن نقل الأكسجين إلى أنسجة الجسم المختلفة.',
            ),
            _ExpandableInfoCard(
              title: 'المواصفات المطلوبة للمتبرع بالدم',
              icon: Icons.person_rounded,
              content:
                  '• أردني الجنسية.\n'
                  '• العمر المناسب للتبرع حسب التعليمات المعتمدة.\n'
                  '• أن يكون بصحة عامة جيدة.\n'
                  '• خلو المتبرع من الأمراض المعدية أو الحالات التي تمنع التبرع.\n'
                  '• الالتزام بتعليمات الفريق الطبي قبل وأثناء وبعد التبرع.',
            ),
            _ExpandableInfoCard(
              title: 'موانع التبرع الدائمة',
              icon: Icons.block_rounded,
              content:
                  '• أمراض الحساسية الشديدة والمزمنة.\n'
                  '• الأمراض المزمنة مثل أمراض القلب الشديدة.\n'
                  '• بعض الأمراض الوراثية أو المناعية حسب تقييم الطبيب.\n'
                  '• أي حالة يقرر الطبيب أنها تشكل خطراً دائماً على المتبرع أو متلقي الدم.',
            ),
            _ExpandableInfoCard(
              title: 'موانع التبرع المؤقتة',
              icon: Icons.schedule_rounded,
              content:
                  'يسمح بالتبرع بالدم بعد الشفاء من بعض الأمراض أو انتهاء فترات المنع المؤقت، مثل:\n'
                  '• بعض الالتهابات أو العدوى البسيطة.\n'
                  '• بعض الإجراءات الطبية المؤقتة.\n'
                  '• حالات يحددها الطبيب بعد الفحص.',
            ),
            _ExpandableInfoCard(
              title: 'خطوات التبرع بالدم',
              icon: Icons.format_list_numbered_rounded,
              content:
                  '1) التسجيل.\n'
                  '2) الإجابة على أسئلة تقييم التبرع.\n'
                  '3) الفحص الطبي السريع والتأكد من الملاءمة.\n'
                  '4) سحب وحدة الدم.\n'
                  '5) الراحة القصيرة وتناول السوائل بعد التبرع.',
            ),
            _ExpandableInfoCard(
              title: 'تعليمات بعد التبرع',
              icon: Icons.local_drink_rounded,
              content:
                  '• أخبر الفريق الطبي فوراً إذا شعرت بأي تعب.\n'
                  '• لا تغادر مركز التبرع مباشرة دون راحة قصيرة.\n'
                  '• أكثر من شرب السوائل خلال اليوم.\n'
                  '• تجنب المجهود البدني العنيف لباقي اليوم.',
            ),
            _ExpandableInfoCard(
              title: 'ردود الفعل المحتملة بعد التبرع',
              icon: Icons.warning_amber_rounded,
              content:
                  'يتحمل معظم المتبرعين التبرع دون مضاعفات، لكن قد يحدث أحياناً:\n'
                  '• دوخة بسيطة.\n'
                  '• تعب مؤقت.\n'
                  '• كدمة خفيفة في موضع الإبرة.\n'
                  'وفي حال استمرار الأعراض، يجب التواصل مع الفريق الطبي.',
            ),
            SizedBox(height: 8),
            Text(
              'المحتوى للتوعية العامة، والقرار الطبي النهائي يكون حسب تقييم الفريق المختص.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: const Row(
        children: [
          Icon(Icons.menu_book_rounded, color: AppTheme.deepRed, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'إرشادات وشروط التبرع بالدم',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;
  const _ExpandableInfoCard({
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ExpansionTile(
        trailing: const Icon(Icons.keyboard_arrow_down_rounded),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(icon, color: AppTheme.deepRed),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              content,
              style: const TextStyle(
                height: 1.6,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
