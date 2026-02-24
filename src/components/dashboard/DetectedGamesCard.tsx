import { useAppStore } from '../../store/appStore';
import Card from '../ui/Card';
import Badge from '../ui/Badge';

export default function DetectedGamesCard() {
  const { detectedGames, isLoading } = useAppStore();

  if (isLoading) {
    return (
      <Card title="Detected Games">
        <div className="animate-pulse space-y-2">
          {[1, 2, 3, 4, 5].map(i => (
            <div key={i} className="h-4 bg-sq-border rounded w-2/3" />
          ))}
        </div>
      </Card>
    );
  }

  return (
    <Card title="Detected Games">
      <div className="space-y-2.5">
        {detectedGames.map((game) => (
          <div key={game.id} className="flex items-center justify-between">
            <span className={`text-sm ${game.installed ? 'text-sq-text' : 'text-sq-text-dim'}`}>
              {game.name}
            </span>
            <Badge variant={game.installed ? 'success' : 'info'}>
              {game.installed ? 'Found' : 'Not Found'}
            </Badge>
          </div>
        ))}
        {detectedGames.length === 0 && (
          <p className="text-xs text-sq-text-dim">Scanning for games...</p>
        )}
      </div>
    </Card>
  );
}
