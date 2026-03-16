import unittest
import sys
import os

# Add parent directory to path to allow import of gozai_agent
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    from gozai_agent.rag_service import SemanticKnowledgeBase, OPTOMETRY_DATA # type: ignore
except ImportError:
    # Use relative import if running within the package directory
    from .rag_service import SemanticKnowledgeBase, OPTOMETRY_DATA # type: ignore
except Exception:
    # Fallback for IDE analysis paths
    from rag_service import SemanticKnowledgeBase, OPTOMETRY_DATA # type: ignore

class TestSemanticKnowledgeBase(unittest.TestCase):
    def setUp(self):
        # Note: In a real CI environment, we would mock the genai.Client
        # for this test. Here we are testing the singleton and data structure.
        self.kb = SemanticKnowledgeBase()

    def test_singleton(self):
        kb2 = SemanticKnowledgeBase()
        self.assertEqual(id(self.kb), id(kb2))

    def test_data_integrity(self):
        self.assertIn("light sensitivity", OPTOMETRY_DATA)
        entry = OPTOMETRY_DATA["light sensitivity"]
        self.assertIn("answer", entry)
        self.assertTrue(len(entry["answer"]) > 10, "Answer text should be non-empty")

    def test_stats_grounding(self):
        # Verify clinical stats are loaded correctly
        try:
            from gozai_agent.rag_service import LOW_VISION_STATS # type: ignore
        except ImportError:
            try:
                from .rag_service import LOW_VISION_STATS # type: ignore
            except Exception:
                from rag_service import LOW_VISION_STATS # type: ignore
        self.assertTrue(len(LOW_VISION_STATS) > 5)
        self.assertIn("global prevalence", LOW_VISION_STATS)

if __name__ == "__main__":
    unittest.main()
