"""Background worker for processing LLM Council jobs."""

import asyncio
from typing import Dict, Any
from . import jobs, storage
from .council import run_full_council


def process_council_job(job_id: str, conversation_id: str, user_query: str) -> Dict[str, Any]:
    """
    Process a council job in the background.
    
    This function is called by RQ worker. It runs the full 3-stage council process
    and updates the job status accordingly.

    Args:
        job_id: Job identifier
        conversation_id: Conversation identifier
        user_query: User's question

    Returns:
        Result dict with stage1, stage2, stage3 data
    """
    try:
        # Update job status to processing
        jobs.update_job_status(job_id, "processing")

        # Run the full council process (this is async, so we need event loop)
        stage1_results, stage2_results, stage3_result, metadata = asyncio.run(
            run_full_council(user_query)
        )

        # Prepare result
        result = {
            "stage1": stage1_results,
            "stage2": stage2_results,
            "stage3": stage3_result,
            "metadata": metadata
        }

        # Update job with result
        jobs.update_job_result(job_id, result)

        # Save to conversation storage
        storage.add_assistant_message(
            conversation_id,
            stage1_results,
            stage2_results,
            stage3_result
        )

        return result

    except Exception as e:
        # Update job with error
        error_msg = f"Error processing job: {str(e)}"
        jobs.update_job_error(job_id, error_msg)
        raise
