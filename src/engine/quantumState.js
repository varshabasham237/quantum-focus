/**
 * QuantumFocusState
 * Models a student's attention as a quantum-inspired superposition of three basis states:
 *   |Focused⟩  |Drifting⟩  |Distracted⟩
 *
 * Probabilities evolve via a Markov-like transition matrix and collapse upon
 * self-report observation (Bayesian update).
 */

const STATES = ['focused', 'drifting', 'distracted'];

// Default transition matrix (per-minute rates)
// Rows = from-state, Cols = to-state
const DEFAULT_TRANSITION = [
  //  F     D     X
  [0.92, 0.06, 0.02],  // from Focused
  [0.15, 0.70, 0.15],  // from Drifting
  [0.05, 0.20, 0.75],  // from Distracted
];

export class QuantumFocusState {
  /**
   * @param {number[]} [initialProbs] — initial probability vector [focused, drifting, distracted]
   * @param {number[][]} [transitionMatrix]
   */
  constructor(initialProbs = [0.6, 0.3, 0.1], transitionMatrix = DEFAULT_TRANSITION) {
    this.probs = [...initialProbs];
    this.T = transitionMatrix.map(r => [...r]);
    this.history = []; // timestamps + snapshots
    this._normalize();
  }

  /* ---- Public API ---- */

  /** Returns {focused, drifting, distracted} probabilities */
  getState() {
    return {
      focused:    this.probs[0],
      drifting:   this.probs[1],
      distracted: this.probs[2],
    };
  }

  /** Dominant state name */
  getDominant() {
    const max = Math.max(...this.probs);
    return STATES[this.probs.indexOf(max)];
  }

  /**
   * Evolve probabilities forward by `dt` minutes.
   * Uses a simple matrix-vector multiplication (Markov chain step).
   */
  evolve(dt = 1) {
    const steps = Math.max(1, Math.round(dt));
    for (let s = 0; s < steps; s++) {
      const newP = [0, 0, 0];
      for (let j = 0; j < 3; j++) {
        for (let i = 0; i < 3; i++) {
          newP[j] += this.probs[i] * this.T[i][j];
        }
      }
      this.probs = newP;
    }
    this._normalize();
    return this.getState();
  }

  /**
   * Collapse the superposition based on a self-report observation.
   * Uses Bayesian-like update: strongly pushes towards the reported state.
   *
   * @param {'focused'|'drifting'|'distracted'} observation
   */
  collapse(observation) {
    const idx = STATES.indexOf(observation);
    if (idx === -1) return;

    // Bayesian-like likelihood: bump observed state, dampen others
    const likelihood = [0.1, 0.1, 0.1];
    likelihood[idx] = 0.8;

    for (let i = 0; i < 3; i++) {
      this.probs[i] *= likelihood[i];
    }
    this._normalize();

    // Also adapt the transition matrix slightly
    this._adaptTransition(idx);

    this.history.push({
      time: Date.now(),
      observation,
      probs: [...this.probs],
    });

    return this.getState();
  }

  /**
   * Predict recommended action based on current probabilities.
   */
  predict() {
    const s = this.getState();
    if (s.distracted > 0.5) {
      return {
        action: 'break',
        message: 'Your distraction probability is high. Consider a short break or a breathing exercise.',
        urgency: 'high',
      };
    }
    if (s.drifting > 0.45) {
      return {
        action: 'refocus',
        message: 'You seem to be drifting. Try re-reading your last paragraph or switching tasks briefly.',
        urgency: 'medium',
      };
    }
    if (s.focused > 0.6) {
      return {
        action: 'continue',
        message: 'Great focus! Keep going — you\'re in the zone.',
        urgency: 'low',
      };
    }
    return {
      action: 'monitor',
      message: 'Your focus state is uncertain. The next check-in will clarify.',
      urgency: 'low',
    };
  }

  /**
   * Compute a focus score 0-100 from the probability vector.
   */
  score() {
    return Math.round(this.probs[0] * 100);
  }

  /**
   * Reset to initial state.
   */
  reset(initialProbs = [0.6, 0.3, 0.1]) {
    this.probs = [...initialProbs];
    this._normalize();
  }

  /**
   * Serialize for localStorage.
   */
  serialize() {
    return {
      probs: this.probs,
      T: this.T,
      history: this.history,
    };
  }

  /**
   * Restore from localStorage data.
   */
  static deserialize(data) {
    const qs = new QuantumFocusState(data.probs, data.T);
    qs.history = data.history || [];
    return qs;
  }

  /* ---- Private ---- */

  _normalize() {
    const sum = this.probs.reduce((a, b) => a + b, 0);
    if (sum > 0) {
      this.probs = this.probs.map(p => p / sum);
    }
  }

  /** Slight reinforcement learning on the transition matrix */
  _adaptTransition(observedIdx) {
    const lr = 0.05; // learning rate
    for (let i = 0; i < 3; i++) {
      this.T[i][observedIdx] += lr;
      // Renormalize row
      const rowSum = this.T[i].reduce((a, b) => a + b, 0);
      this.T[i] = this.T[i].map(v => v / rowSum);
    }
  }
}
