import 'dart:math';

class EloService {
  static const double kFactor = 1.5;
  static const double kScaleFactor = 4.0;

  /// Returns (newWinnerRating, newLoserRating)
  (double, double) calculateNewRatings(double winnerRating, double loserRating) {
    final expectedWinner = 1.0 / (1.0 + pow(10, (loserRating - winnerRating) / kScaleFactor));
    final expectedLoser = 1.0 / (1.0 + pow(10, (winnerRating - loserRating) / kScaleFactor));

    final newWinner = double.parse((winnerRating + kFactor * (1.0 - expectedWinner)).toStringAsFixed(2));
    final newLoser = double.parse((loserRating + kFactor * (0.0 - expectedLoser)).toStringAsFixed(2));

    return (newWinner, newLoser);
  }
}
