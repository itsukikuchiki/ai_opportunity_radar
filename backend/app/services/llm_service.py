class LlmService:
    def generate_weekly(self, payload: dict) -> dict:
        top_pattern = (payload.get('patterns') or [{}])[0]
        top_friction = (payload.get('frictions') or [{}])[0]
        opp = (payload.get('opportunities') or [None])[0]
        return {
            'key_insight': '你最近真正消耗精力的，不是事情太多，而是每次开始前都要重建上下文。',
            'top_patterns': [
                {
                    'id': top_pattern.get('id', 'pattern_demo'),
                    'name': top_pattern.get('name', '重复资料整理'),
                    'summary': top_pattern.get('description', '你常在开始行动前先重新找资料、整理信息。'),
                    'strength': 'strong',
                }
            ] if top_pattern else [],
            'top_frictions': [
                {
                    'id': top_friction.get('id', 'friction_demo'),
                    'name': top_friction.get('name', '上下文分散导致启动困难'),
                    'summary': top_friction.get('description', '问题不在执行，而在开始前的重新组织。'),
                }
            ] if top_friction else [],
            'best_action': '这周先把最常重复的一类资料固定到一个入口，减少启动前的整理成本。',
            'opportunity_snapshot': {
                'id': opp.get('id', 'opp_demo'),
                'name': opp.get('name', '资料预整理 Copilot'),
                'summary': opp.get('description', '这类重复准备工作已经具备 Copilot 化的条件。'),
                'maturity': opp.get('maturity', 'emerging'),
            } if opp else None,
        }

    def generate_opportunity_explanation(self, payload: dict) -> dict:
        return {
            'why_this_opportunity': '过去几周里，你反复在开始任务前重新收集和整理资料，这让启动成本持续偏高。',
            'evidence_summary': [
                '相关模式近几周持续出现',
                '主要摩擦集中在信息分散与启动困难',
                '你也表达过希望把这一步省掉',
            ],
            'solution_fit_explanation': '这类问题已经有比较清楚的输入和输出，适合先做 Copilot，而不是直接交给全自动 Agent。',
            'next_step': '先试一个最小版本：输入任务主题后，自动聚合相关资料并输出起步草稿。',
            'user_facing_summary': '这不是一个要你彻底改变习惯的问题，而是一个适合让 AI 先接管前置整理的机会。',
        }

    def generate_followup_question(self, payload: dict) -> dict:
        return {
            'question_type': 'information_friction_detail',
            'question_text': '你最烦的是找资料，还是整理结构？',
            'options': [
                {'label': '找资料', 'value': 'find_info'},
                {'label': '整理结构', 'value': 'organize_structure'},
                {'label': '重新写', 'value': 'rewrite'},
                {'label': '先跳过', 'value': 'skip'},
            ],
        }
